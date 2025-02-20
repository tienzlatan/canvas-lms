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
require_relative '../helpers/quizzes_common'

describe 'quiz taking' do
  include_context 'in-process server selenium tests'
  include QuizzesCommon

  before do
    course_with_student_logged_in(active_all: true)
    @quiz = quiz_with_new_questions(goto_edit: false)
  end

  it 'toggles only the essay question that was toggled leaving others on the page alone',
     custom_timeout: 30 do
    @quiz = quiz_with_essay_questions(false)
    get "/courses/#{@course.id}/quizzes/#{@quiz.id}"
    expect_new_page_load { f('#take_quiz_link').click }
    wait_for_ajaximations

    links = ff('[data-btn-id="rce-edit-btn"]')

    # the first RCE
    expect(links[0].text).to include('Switch to the html editor')
    expect(links[0]).to be_displayed

    # the second RCE
    expect(links[1].text).to include('Switch to the html editor')
    expect(links[1]).to be_displayed
    links[0].click

    # Retrieve the links again
    links = ff('[data-btn-id="rce-edit-btn"]')

    # first rce is now html
    expect(links[0].text).to include('Switch to the rich text editor')
    expect(links[0]).to be_displayed

    # second RCE is unchanged
    expect(links[1].text).to include('Switch to the html editor')
    expect(links[1]).to be_displayed
  end

  it 'allows to take the quiz as long as there are attempts left',
     :xbrowser,
     priority: '1',
     test_id: 140_606,
     custom_timeout: 30 do
    @quiz.allowed_attempts = 2
    @quiz.save!
    get "/courses/#{@course.id}/quizzes/#{@quiz.id}"
    expect_new_page_load { f('#take_quiz_link').click }
    answer_questions_and_submit(@quiz, 2)
    expect(f('#take_quiz_link')).to be_present
    expect_new_page_load { f('#take_quiz_link').click }
    answer_questions_and_submit(@quiz, 2)
    expect(f('#content')).not_to contain_css('#take_quiz_link')
  end

  it 'shows take quiz button for admins enrolled as a student' do
    course_with_teacher(user: @student, course: @course)
    get "/courses/#{@course.id}/quizzes/#{@quiz.id}"
    expect(f('#take_quiz_link')).to be_present
  end

  it 'shows a prompt when attempting to submit with unanswered questions',
     priority: '1',
     test_id: 140_608 do
    skip_if_safari(:alert)
    get "/courses/#{@course.id}/quizzes/#{@quiz.id}"
    expect_new_page_load { f('#take_quiz_link').click }

    # answer just one question
    question = @quiz.stored_questions[0][:id]
    fj("input[type=radio][name= 'question_#{question}']").click
    f('#submit_quiz_button').click

    # expect alert prompt to show, dismiss and answer the remaining questions
    expect(driver.switch_to.alert.text).to be_present
    dismiss_alert
    question = @quiz.stored_questions[1][:id]
    fj("input[type=radio][name= 'question_#{question}']").click
    expect_new_page_load { f('#submit_quiz_button').click }
    expect(f('.quiz-submission .quiz_score .score_value')).to be_displayed
  end

  it 'should not restrict whitelisted ip addresses', priority: '1'

  it 'accounts for question group settings', priority: '1' do
    skip_if_chrome('research')
    quiz = quiz_model
    bank = AssessmentQuestionBank.create!(context: @course)
    3.times do
      assessment_question_model(bank: bank)
      question = bank.assessment_questions.last
      question.question_data[:points_possible] = 1
      question.save!
    end
    quiz.quiz_groups.create(
      pick_count: 2,
      question_points: 15,
      assessment_question_bank_id: bank.id
    )
    quiz.generate_quiz_data

    # published_at time should be greater than edited_at ime for changes to be committed
    quiz.published_at = Time.zone.now
    quiz.save!
    get "/courses/#{@course.id}/quizzes"
    expect(f('#assignment-quizzes li:nth-of-type(2)').text).to include('30 pts')
    get "/courses/#{@course.id}/quizzes/#{quiz.id}"
    expect_new_page_load { f('#take_quiz_link').click }
    2.times do |o|
      expect(fj("#question_#{quiz.quiz_questions[o].id} .question_points_holder")).to include_text(
        '15 pts'
      )
      click_option("#question_#{quiz.quiz_questions[o].id} .question_input:nth-of-type(1)", 'a1')
      click_option("#question_#{quiz.quiz_questions[o].id} .question_input:nth-of-type(2)", 'a3')
    end
    submit_quiz
    expect(f('.quiz-submission .quiz_score .score_value')).to include_text('30')
  end
end
