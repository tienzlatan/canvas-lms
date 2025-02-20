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

require_relative '../helpers/conversations_common'
require_relative '../helpers/assignment_overrides'

describe "conversations new" do
  include_context "in-process server selenium tests"
  include AssignmentOverridesSeleniumHelper
  include ConversationsCommon

  let(:account) { Account.default }
  let(:account_settings_url) { "/accounts/#{account.id}/settings" }
  let(:user_notes_url) { "/courses/#{@course.id}/user_notes" }
  let(:student_user_notes_url) { "/users/#{@s1.id}/user_notes" }

  before do
    conversation_setup
    @s1 = user_factory(name: "first student")
    @s2 = user_factory(name: "second student")
    @s3 = user_factory(name: 'third student')
    [@s1, @s2, @s3].each { |s| @course.enroll_student(s).update_attribute(:workflow_state, 'active') }
    cat = @course.group_categories.create(:name => "the groups")
    @group = cat.groups.create(:name => "the group", :context => @course)
    @group.users = [@s1, @s2]
  end

  context "Course with Faculty Journal not enabled" do
    before do
      site_admin_logged_in
    end

    it "allows a site admin to enable faculty journal", priority: "2" do
      get account_settings_url
      f('#account_enable_user_notes').click
      f('.Button.Button--primary[type="submit"]').click
      wait_for_ajaximations
      expect(is_checked('#account_enable_user_notes')).to be_truthy
    end
  end

  context "Course with Faculty Journal enabled" do
    before do
      site_admin_logged_in
      @course.account.update_attribute(:enable_user_notes, true)
    end

    it "checks the Journal messages for correct time and sender", priority: "1" do
      user_session(@teacher)
      conversations
      compose course: @course, subject: 'Christmas', to: [@s1], body: 'The Fat Man cometh.', journal: true, send: true
      time = format_time_for_view(UserNote.last.updated_at)
      get student_user_notes_url
      expect(f('.subject')).to include_text('Christmas')
      expect(f('.user_content').text).to eq 'The Fat Man cometh.'
      expect(f('.creator_name')).to include_text(@teacher.name)
      expect(f('.creator_name')).to include_text(time)
    end

    it "allows an admin to delete a Journal message", priority: "1" do
      skip_if_safari(:alert)
      user_session(@teacher)
      conversations
      compose course: @course, subject: 'Christmas', to: [@s1], body: 'The Fat Man cometh.', journal: true, send: true
      get student_user_notes_url
      f('.delete_link').click
      driver.switch_to.alert.accept
      wait_for_ajaximations
      expect(f('.title.subject').text).to eq('')
      get student_user_notes_url
      expect(f('.title.subject').text).to eq('')
    end

    it "allows a new entry by an admin", priority: "1" do
      get student_user_notes_url
      f('#new_user_note_button').click
      wait_for_ajaximations # wait for the form to `.slideDown()`
      replace_content(f('#user_note_title'), 'FJ Title 2')
      replace_content(f('textarea'), 'FJ Body text 2')
      f('.send_button').click
      wait_for_ajaximations
      time = format_time_for_view(UserNote.last.updated_at)
      get student_user_notes_url
      expect(f('.subject').text).to eq 'FJ Title 2'
      expect(f('.user_content').text).to eq 'FJ Body text 2'
      expect(f('.creator_name')).to include_text(time)
    end

    it "should clear the subject and body when cancel is clicked", priority: "1"
  end

  context "Faculty Journal" do
    before do
      @course.account.update_attribute(:enable_user_notes, true)
      user_session(@teacher)
      conversations
    end

    it "goes to the user_notes page", priority: "1" do
      get user_notes_url
      expect(f('#breadcrumbs')).to include_text('Faculty Journal')
    end

    it "is allowed on new private conversations with students", priority: "1" do
      compose course: @course, to: [@s1, @s2], body: 'hallo!', send: false
      checkbox = f('.user_note')
      expect(checkbox).to be_displayed
      checkbox.click
      count1 = @s1.user_notes.count
      count2 = @s2.user_notes.count
      click_send
      expect(@s1.user_notes.reload.count).to eq count1 + 1
      expect(@s2.user_notes.reload.count).to eq count2 + 1
    end

    it "is allowed with student groups", priority: "1" do
      compose course: @course, to: [@group], body: 'hallo!', send: false
      checkbox = f('.user_note')
      expect(checkbox).to be_displayed
      checkbox.click
      count1 = @s1.user_notes.count
      click_send
      expect(@s1.user_notes.reload.count).to eq count1 + 1
    end

    it "is not allowed if disabled", priority: "1" do
      @course.account.update_attribute(:enable_user_notes, false)
      conversations
      compose course: @course, to: [@s1], body: 'hallo!', send: false
      expect(f('.user_note')).not_to be_displayed
    end

    it "is not allowed for students", priority: "1" do
      user_session(@s1)
      conversations
      compose course: @course, to: [@s2], body: 'hallo!', send: false
      expect(f('.user_note')).not_to be_displayed
    end

    it "is not allowed with non-student recipient", priority: "1" do
      compose course: @course, to: [@teacher], body: 'hallo!', send: false
      expect(f('.user_note')).not_to be_displayed
    end

    it "has the Journal entry checkbox come back unchecked", priority: "1" do
      f('#compose-btn').click
      wait_for_ajaximations
      expect(f('.user_note')).not_to be_displayed

      select_message_course(@course)
      add_message_recipient(@s1)
      write_message_body('Give the Turkey his day')

      expect(f('.user_note')).to be_displayed
      add_message_recipient(@s2)
      checkbox = f('.user_note')
      expect(checkbox).to be_displayed
      checkbox.click
      expect(is_checked('.user_note')).to be_present
      hover_and_click('.ac-token-remove-btn')
      expect(f('.user_note')).not_to be_displayed
      add_message_recipient(@s3)
      expect(is_checked('.user_note')).not_to be_present
    end

    it "has the Journal entry checkbox visible", priority: "1" do
      f('#compose-btn').click
      wait_for_ajaximations
      expect(f('.user_note')).not_to be_displayed

      select_message_course(@course)
      add_message_recipient(@s1)
      write_message_body('Give the Turkey his day')
      expect(f('.user_note')).to be_displayed
      add_message_recipient(@s2)
      expect(f('.user_note')).to be_displayed
    end

    it "sends a message with faculty journal checked", priority: "1" do
      conversations
      # First verify teacher can send a message with faculty journal entry checked to one student
      compose course: @course, to: [@s1], body: 'hallo!', journal: true, send: true
      expect_flash_message :success, "Message sent!"
      # Now verify adding another user while the faculty journal entry checkbox is checked doesn't uncheck it and
      #   still lets teacher know it was sent successfully.
      fj('.ic-flash-success:last').click
      compose course: @course, to: [@s1], body: 'hallo!', journal: true, send: false
      add_message_recipient(@s2)
      expect(is_checked('.user_note')).to be_truthy
      click_send
      expect_flash_message :success, "Message sent!"
    end
  end
end
