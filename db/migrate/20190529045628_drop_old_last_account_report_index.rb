# frozen_string_literal: true

#
# Copyright (C) 2019 - present Instructure, Inc.
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

class DropOldLastAccountReportIndex < ActiveRecord::Migration[5.1]
  tag :postdeploy

  def up
    remove_index :account_reports, name: 'index_account_reports_latest_per_account'
  end

  def down
    add_index :account_reports, %i[account_id report_type updated_at],
              order: { updated_at: :desc },
              name: 'index_account_reports_latest_per_account'
  end
end
