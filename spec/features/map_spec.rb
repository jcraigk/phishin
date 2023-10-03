require 'rails_helper'

describe 'Venues page', :js do
  it 'visit Venues page' do
    visit map_path

    within('#title_box') do
      expect_content('Find shows near:', 'within', 'miles', 'within date range')
      expect_css('#map_search_term', '#map_search_distance', '#map_date_start', '#map_date_stop')
    end

    within('#content_box') do
      expect_css('#map')
    end
  end
end
