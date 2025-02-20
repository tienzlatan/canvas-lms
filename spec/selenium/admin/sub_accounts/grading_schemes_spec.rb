# frozen_string_literal: true

#
# Copyright (C) 2012 - present Instructure, Inc.
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

require_relative '../../common'
require_relative '../../helpers/grading_schemes_common'

describe "sub account grading schemes" do
  include_context "in-process server selenium tests"
  include GradingSchemesCommon

  let(:account) { Account.create(:name => 'sub account from default account', :parent_account => Account.default) }
  let(:url) { "/accounts/#{account.id}/grading_standards" }

  before do
    course_with_admin_logged_in
    get url
    f('#react_grading_tabs a[href="#grading-standards-tab"]').click
  end

  describe "grading schemes" do
    it "adds a grading scheme", priority: "1" do
      should_add_a_grading_scheme
    end

    it "edits a grading scheme", priority: "1" do
      should_edit_a_grading_scheme(account, url)
    end

    it "deletes a grading scheme", priority: "1" do
      skip_if_safari(:alert)
      should_delete_a_grading_scheme(account, url)
    end

    it 'disables add grading scheme button during update', priority: "2" do
      simple_grading_standard(account)
      get url
      f('#react_grading_tabs a[href="#grading-standards-tab"]').click
      f('.edit_grading_standard_button').click
      expect(f('#react_grading_tabs .add_standard_button')).to have_class('disabled')
    end

    it 'disables other grading schemes from being edited', priority: "2" do
      2.times do
        simple_grading_standard(account)
      end
      get url
      f('#react_grading_tabs a[href="#grading-standards-tab"]').click
      f('.edit_grading_standard_button').click
      expect(f('.disabled-buttons')).to be_truthy
    end

    it 'allows all available grading schemes to be edited on page load', priority: "2" do
      2.times do
        simple_grading_standard(account)
      end
      get url
      f('#react_grading_tabs a[href="#grading-standards-tab"]').click
      expect(ff('.standard_title .links').count).to eq(2)
    end
  end

  describe "grading scheme items" do
    before do
      create_simple_standard_and_edit(account, url)
    end

    it "adds a grading scheme item", priority: "1" do
      should_add_a_grading_scheme_item
    end

    it "edits a grading scheme item", priority: "1" do
      should_edit_a_grading_scheme_item
    end

    it "deletes a grading scheme item", priority: "1" do
      should_delete_a_grading_scheme_item
    end

    it "does not update when invalid scheme input is given", priority: "1" do
      should_not_update_invalid_grading_scheme_input
    end
  end
end
