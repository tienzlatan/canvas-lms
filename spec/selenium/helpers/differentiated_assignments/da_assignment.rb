# frozen_string_literal: true

#
# Copyright (C) 2016 - present Instructure, Inc.
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

require_relative '../spec_components/spec_components_assignment'
require_relative 'da_wrappable'

module DifferentiatedAssignments
  class Assignment < SpecComponents::Assignment
    include DifferentiatedAssignmentsWrappable

    def initialize(assignees)
      initialize_assignees(assignees)
      super(course: DifferentiatedAssignments.the_course, title: "Assignment for #{assignees_list}")
    end
  end
end
