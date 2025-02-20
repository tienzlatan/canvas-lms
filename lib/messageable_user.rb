# frozen_string_literal: true

#
# Copyright (C) 2013 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

class MessageableUser < User
  COLUMNS = %w[id updated_at pronouns short_name name avatar_image_url avatar_image_source].map { |col| "users.#{col}" }
  SELECT = COLUMNS.join(", ")
  AVAILABLE_CONDITIONS = "users.workflow_state IN ('registered', 'pre_registered')"

  def self.build_select(options = {})
    options = {
      :common_course_column => nil,
      :common_group_column => nil,
      :common_role_column => nil
    }.merge(options)

    bookmark_sql = User.sortable_name_order_by_clause

    common_course_sql =
      if options[:common_role_column]
        raise ArgumentError unless options[:common_course_column]

        connection.func(:group_concat,
                        :"#{options[:common_course_column]}::text || ':' || #{options[:common_role_column]}::text")
      else
        'NULL::text'
      end

    common_group_sql =
      if options[:common_group_column].is_a?(String)
        connection.func(:group_concat, options[:common_group_column].to_sym)
      elsif options[:common_group_column]
        options[:common_group_column].to_s
      else
        'NULL::text'
      end

    "#{SELECT}, #{bookmark_sql} AS bookmark, #{common_course_sql} AS common_courses, #{common_group_sql} AS common_groups"
  end

  def self.prepped(options = {})
    options = {
      :strict_checks => true,
      :include_deleted => false
    }.merge(options)

    # if either of our common course/group id columns are column names (vs.
    # integers), they need to go in the group by. we turn the first element
    # into an array and add them to that, so that both postgresql/mysql are
    # happy (see the documentation on group_concat if you're curious about
    # the gory details)
    columns = COLUMNS.dup
    if options[:common_course_column].is_a?(String) || options[:common_group_column].is_a?(String)
      head = [columns.shift]
      head << options[:common_course_column] if options[:common_course_column].is_a?(String)
      head << options[:common_group_column] if options[:common_group_column].is_a?(String)
      columns.unshift(head)
    end

    scope = self
            .select(MessageableUser.build_select(options))
            .group(MessageableUser.connection.group_by(*columns))
            .order(User.sortable_name_order_by_clause).order(Arel.sql("users.id"))

    if options[:strict_checks]
      scope.where(AVAILABLE_CONDITIONS)
    elsif !options[:include_deleted]
      scope.where("users.workflow_state <> 'deleted'")
    else
      scope
    end
  end

  def self.unfiltered(options = {})
    prepped(options.merge(:strict_checks => false))
  end

  def self.available(options = {})
    prepped(options.merge(:strict_checks => true))
  end

  def self.context_recipients(recipients)
    recipients.grep(Calculator::CONTEXT_RECIPIENT)
  end

  def self.individual_recipients(recipients)
    recipients.select do |id|
      !id.is_a?(String) ||
        id =~ Calculator::INDIVIDUAL_RECIPIENT
    end.map(&:to_i)
  end

  def common_groups
    common_contexts_on_current_shard(global_common_groups)
  end

  def common_courses
    common_contexts_on_current_shard(global_common_courses)
  end

  # only MessageableUser::Calculator should access these directly. if you're
  # outside the calculator, you almost certainly want the versions above that
  # transpose to the current shard. additionally, any time you access these,
  # make sure you're still on the same shard where common_course_id and/or
  # common_group_id were queried
  attr_accessor :global_common_courses, :global_common_groups

  # this will be executed on the shard where the find was called (I think?).
  # as such, we can correctly interpret local ids in the common_courses and
  # common_groups
  def populate_common_contexts
    @global_common_courses = {}
    read_attribute(:common_courses)&.to_s&.split(',')&.each do |common_course|
      course_id, role = common_course.split(':')
      course_id = course_id.to_i
      # a course id of 0 indicates admin visibility without an actual shared
      # course; don't "globalize" it
      course_id = Shard.global_id_for(course_id) unless course_id.zero?
      @global_common_courses[course_id] ||= []
      @global_common_courses[course_id] << role
    end

    @global_common_groups = {}
    read_attribute(:common_groups)&.to_s&.split(',')&.each do |group_id|
      group_id = Shard.global_id_for(group_id.to_i)
      @global_common_groups[group_id] ||= []
      @global_common_groups[group_id] << 'Member'
    end
  end
  after_find :populate_common_contexts

  def include_common_contexts_from(other)
    combine_common_contexts(global_common_courses, other.global_common_courses)
    combine_common_contexts(global_common_groups, other.global_common_groups)
  end

  def serializable_hash(options = {})
    options[:except] ||= []
    options[:except] << :bookmark
    super(options)
  end

  private

  def common_contexts_on_current_shard(common_contexts)
    local_common_contexts = {}
    target_shard = Shard.current
    return local_common_contexts if common_contexts.empty?

    Shard.partition_by_shard(common_contexts.keys) do |sharded_ids|
      sharded_ids.each do |id|
        # a context id of 0 indicates admin visibility without an actual shared
        # context; don't "globalize" it
        global_id = id == 0 ? id : Shard.global_id_for(id)
        id = global_id unless Shard.current == target_shard
        local_common_contexts[id] = common_contexts[global_id]
      end
    end
    local_common_contexts
  end

  def combine_common_contexts(left, right)
    right.each { |key, values| (left[key] ||= []).concat(values) }
  end

  # both bookmark_for and restrict_scope should always be executed on the
  # same shard (not guaranteed, but we don't have to guarantee correctness if
  # they aren't). so local ids here and local ids there have identical
  # interpretation: local to Shard.current.
  class MessageableUser::Bookmarker
    def self.bookmark_for(user)
      [user.bookmark, user.id]
    end

    def self.validate(bookmark)
      bookmark.is_a?(Array) &&
        bookmark.size == 2 &&
        bookmark[0].is_a?(String) &&
        bookmark[1].is_a?(Integer)
    end

    # ordering is already guaranteed
    def self.restrict_scope(scope, pager)
      if pager.current_bookmark
        name, id = pager.current_bookmark
        if MessageableUser.connection.adapter_name == 'PostgreSQL'
          name = MessageableUser.connection.escape_bytea(name)
        end
        scope_shard = scope.shard_value
        id = Shard.relative_id_for(id, Shard.current, scope_shard) if scope_shard

        condition = [
          <<~SQL.squish,
            #{User.sortable_name_order_by_clause} > ? OR
            #{User.sortable_name_order_by_clause} = ? AND users.id > ?
          SQL
          name, name, id
        ]

        if pager.include_bookmark
          condition[0] << "OR #{User.sortable_name_order_by_clause} = ? AND users.id = ?"
          condition.concat([name, id])
        end

        scope.where(condition)
      else
        scope
      end
    end
  end
end
