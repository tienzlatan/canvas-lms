# frozen_string_literal: true

#
# Copyright (C) 2014 - present Instructure, Inc.
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

require 'active_support/callbacks'

# Used to maintain a registry of which callbacks have been suspended for which
# kinds (e.g. :save) and types (e.g. :before) in a specific scope.
module ActiveSupport::Callbacks
  module Suspension
    class Registry
      def initialize
        @callbacks = {}
      end

      def any_registered?(kind)
        return true if !kind.nil? && any_registered?(nil)

        types = @callbacks[kind]
        return false if types.nil?
        return false if types.empty?

        types.each_value do |cbs|
          return true unless cbs.empty?
        end

        false
      end

      def [](kind, type)
        if @callbacks.key?(kind) && @callbacks[kind].key?(type)
          @callbacks[kind][type]
        else
          []
        end
      end

      def []=(kind, type, value)
        @callbacks[kind] ||= {}
        @callbacks[kind][type] = value
      end

      # registers each of the callbacks for each of the kinds and types. if
      # kinds and/or types is empty, it means to register the callbacks for all
      # kinds and/or all types, respectively. if callbacks is empty, it means
      # to register a blanket for the kinds and types. see include?(...) below.
      #
      # returns the delta from what was already registered, so that it can be
      # reverted later (see revert(...) below).
      def update(callbacks, kinds, types)
        callbacks << nil if callbacks.empty?
        kinds << nil if kinds.empty?
        types << nil if types.empty?

        delta = self.class.new
        kinds.each do |kind|
          types.each do |type|
            delta[kind, type] = callbacks - self[kind, type]
            self[kind, type] += delta[kind, type]
          end
        end
        delta
      end

      # removes the registrations from an earlier update.
      def revert(delta)
        delta.each do |kind, type, callbacks|
          self[kind, type] -= callbacks
        end
      end

      # checks if the callback has been registered for that kind (e.g. :save) and
      # type (e.g. :before) via any of the following:
      #
      #  * explicitly for that kind and that type (e.g. update([:validate], [:save], [:before])),
      #  * explicitly for all kinds and that type (e.g. update([:validate], [], [:before])),
      #  * explicitly for that kind and all types (e.g. update([:validate], [:save], [])),
      #  * explicitly for all kinds and all types (e.g. update([:validate], [], [])),
      #  * a blanket for that kind and that type (e.g. update([], [:save], [:before]),
      #  * a blanket for all kinds and that type (e.g. update([], [], [:before])),
      #  * a blanket for that kind and all types (e.g. update([], [:save], [])),
      #  * a blanket for all kinds and all types (e.g. update([], [], []))
      def include?(callback, kind, type)
        [self[kind, type],
         self[kind, nil],
         self[nil, type],
         self[nil, nil]].any? do |cbs|
          cbs.include?(nil) ||
            cbs.include?(callback)
        end
      end

      def each
        @callbacks.each do |kind, callbacks|
          callbacks.each do |type, skipped|
            yield kind, type, skipped
          end
        end
      end
    end
  end
end
