# frozen_string_literal: true

#
# Copyright (C) 2018 - present Instructure, Inc.
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

module Api::V1::ModerationGrader
  include Api::V1::Json

  def moderation_graders_json(assignment, user, session)
    states = %w[inactive completed deleted invited]
    active_user_ids = assignment.course.instructors.where.not(enrollments: { workflow_state: states }).pluck(:id)

    provisional_graders = assignment.provisional_moderation_graders
    if assignment.can_view_other_grader_identities?(user)
      graders = provisional_graders.preload(:user)
      graders_by_id = graders.index_by(&:id)

      api_json(graders, user, session, only: %w[id user_id]).tap do |hash|
        hash.each do |grader_json|
          grader_json['grader_name'] = graders_by_id[grader_json['id']].user.short_name
          grader_json['grader_selectable'] = active_user_ids.include?(grader_json['user_id'])
        end
      end
    else
      active_user_ids.map! { |id| assignment.grader_ids_to_anonymous_ids[id.to_s] }
      api_json(provisional_graders, user, session, only: %w[id anonymous_id])
        .each { |grader_json| grader_json['grader_selectable'] = active_user_ids.include?(grader_json['anonymous_id']) }
    end
  end
end
