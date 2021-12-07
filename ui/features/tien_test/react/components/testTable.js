/*
 * Copyright (C) 2018 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// import I18n from 'i18n!testTable'
import React, {useState, useEffect} from 'react'
import '@canvas/rails-flash-notifications'
import axios from 'axios'

import {Table} from '@instructure/ui-table'

const TestTable = () => {
  const [tableData, setTableData] = useState([])

  useEffect(() => {
    axios({
      method: 'get',
      url: '/api/hrp/courses/1/module_items'
    })
      .then(res => {
        const formattedTableData = []
        res.data.forEach(m => {
          m.items.forEach(tag => {
            formattedTableData.push({
              ...tag,
              module: m.module
            })
          })
        })

        setTableData(formattedTableData)
      })
      .catch(err => {
        console.log(err)
      })
  }, [])

  return (
    <div>
      <Table caption="Test Table">
        <Table.Head>
          <Table.Row>
            <Table.ColHeader id="Title">Title</Table.ColHeader>
            <Table.ColHeader id="ContentType">Content Type</Table.ColHeader>
            <Table.ColHeader id="QuizLTI">Quiz LTI</Table.ColHeader>
            <Table.ColHeader id="Module">Module</Table.ColHeader>
          </Table.Row>
        </Table.Head>
        <Table.Body>
          {tableData.map(row => (
            <Table.Row>
              <Table.RowHeader>{row.title}</Table.RowHeader>
              <Table.Cell>{row.content_type}</Table.Cell>
              <Table.Cell>{row.quiz_lti.toString()}</Table.Cell>
              <Table.Cell>{row.module}</Table.Cell>
            </Table.Row>
          ))}
        </Table.Body>
      </Table>
    </div>
  )
}

export default TestTable
