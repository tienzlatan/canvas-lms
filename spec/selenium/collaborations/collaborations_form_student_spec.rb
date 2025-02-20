# frozen_string_literal: true

#
# Copyright (C) 2015 - present Instructure, Inc.
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

require_relative '../common'
require_relative '../helpers/collaborations_common'
require_relative '../helpers/collaborations_specs_common'
require_relative '../helpers/google_drive_common'

describe "collaborations" do
  include_context "in-process server selenium tests"
  include CollaborationsCommon
  include CollaborationsSpecsCommon
  include GoogleDriveCommon

  context "a student's" do
    title = 'Google Docs'
    type = 'google_docs'

    context "#{title} collaboration" do
      before do
        course_with_student_logged_in
        setup_google_drive
      end

      it 'displays the new collaboration form if there are no existing collaborations', priority: "1" do
        new_collaborations_form(type)
      end

      it 'does not display the new collaboration form if other collaborations exist', priority: "1" do
        not_display_new_form_if_none_exist(type, title)
      end

      it 'opens the new collaboration form if the last collaboration is deleted', priority: "1" do
        open_form_if_last_was_deleted(type, title)
      end

      it 'does not display the new collaboration form when the penultimate collaboration is deleted', priority: "1" do
        not_display_new_form_when_penultimate_collaboration_is_deleted(type, title)
      end

      it 'leaves the new collaboration form open when the last collaboration is deleted', priority: "1" do
        leave_new_form_open_when_last_is_deleted(type, title)
      end

      it 'selects collaborators', priority: "1" do
        select_collaborators(type)
      end

      it 'deselects collaborators', priority: "1" do
        deselect_collaborators(type)
      end

      context '#add_collaboration fragment' do
        it 'displays the new collaboration form if no collaborations exist', priority: "2" do
          display_new_form_if_none_exist(type)
        end

        it 'hides the new collaboration form if collaborations exist', priority: "2" do
          hide_new_form_if_exists(type, title)
        end
      end
    end

    context "a students's etherpad collaboration" do
      before do
        course_with_teacher(:active_all => true, :name => 'teacher@example.com')
        student_in_course(:course => @course, :name => 'Don Draper')
      end

      it 'does not show groups the student does not belong to', priority: "1" do
        PluginSetting.create!(:name => 'etherpad', :settings => {})
        group1 = "grup grup"

        group_model(:context => @course, :name => group1)
        @group.add_user(@student)
        group_model(:context => @course, :name => "other grup")

        user_session(@student)
        get "/courses/#{@course.id}/collaborations"
        dismiss_flash_messages

        move_to_click('label[for=groups-filter-btn-new]')
        wait_for_ajaximations

        expect(ffj('.available-groups:visible a').count).to eq 1
        expect(fj('.available-groups:visible a')).to include_text(group1)
      end
    end
  end
end
