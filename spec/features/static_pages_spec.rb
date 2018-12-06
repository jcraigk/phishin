# frozen_string_literal: true
require 'rails_helper'

feature 'Static pages', :js do
  scenario 'visit Legal page' do
    visit '/legal'

    within('#title_box') do
      expect_content('Legal Stuff')
    end

    within('#content_box') do
      expect_content('This site complies with Phish\'s official taping policy')
    end
  end

  scenario 'visit Contact page' do
    visit '/contact'

    within('#title_box') do
      expect_content('Contact')
    end

    within('#content_box') do
      expect_content('I woke up one morning in November')
    end
  end

  scenario 'visit API Docs page' do
    visit '/api-docs'

    within('#title_box') do
      expect_content('API Documentation')
    end

    within('#content_box') do
      expect_content('Requests', 'Responses', 'Parameters', 'Endpoints')
    end
  end
end
