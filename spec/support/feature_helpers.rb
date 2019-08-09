# frozen_string_literal: true
module FeatureHelpers
  def expect_content(*args)
    args.each { |c| expect_content_single(c) }
  end

  def expect_content_single(content)
    expect(page).to have_content(content)
  end

  def expect_css(*args)
    args.each { |c| expect_css_single(c) }
  end

  def expect_css_single(css)
    expect(page).to have_css(css)
  end

  def expect_content_in_order(*args)
    args[0..-2].each_with_index do |c, idx|
      expect(c).to appear_before(args[idx + 1])
    end
  end

  def expect_track_sorting_controls(tracks) # rubocop:disable Metrics/AbcSize
    titles_by_date = tracks.sort_by { |t| t.show.date }.map(&:title)
    titles_by_likes = tracks.sort_by(&:likes_count).map(&:title)
    titles_by_duration = tracks.sort_by(&:duration).map(&:title)

    # Default sort by Reverse date
    within('#title_box') do
      expect_content('Sort by', 'Reverse Date')
    end
    expect_content_in_order(titles_by_date.reverse)

    # Sort by Date
    within('#title_box') do
      first('.dropdown-toggle').click
      click_link('Date')
      expect_content('Sort by', 'Date')
    end
    expect_content_in_order(titles_by_date)

    # Sort by Likes
    within('#title_box') do
      first('.dropdown-toggle').click
      click_link('Likes')
      expect_content('Sort by', 'Likes')
    end
    expect_content_in_order(titles_by_likes)

    # Sort by Duration
    within('#title_box') do
      first('.dropdown-toggle').click
      click_link('Duration')
      expect_content('Sort by', 'Duration')
    end
    expect_content_in_order(titles_by_duration)
  end

  def expect_show_sorting_controls(shows) # rubocop:disable Metrics/AbcSize
    dates_by_date = shows.sort_by(&:date).map(&:date_with_dots)
    dates_by_likes = shows.sort_by(&:likes_count).map(&:date_with_dots)
    dates_by_duration = shows.sort_by(&:duration).map(&:date_with_dots)

    # Default sort by Reverse date
    within('#title_box') do
      expect_content('Sort by', 'Reverse Date')
    end
    expect_content_in_order(dates_by_date.reverse)

    # Sort by Date
    within('#title_box') do
      first('.dropdown-toggle').click
      click_link('Date')
      expect_content('Sort by', 'Date')
    end
    expect_content_in_order(dates_by_date)

    # Sort by Likes
    within('#title_box') do
      first('.dropdown-toggle').click
      click_link('Likes')
      expect_content('Sort by', 'Likes')
    end
    expect_content_in_order(dates_by_likes)

    # Sort by Duration
    within('#title_box') do
      first('.dropdown-toggle').click
      click_link('Duration')
      expect_content('Sort by', 'Duration')
    end
    expect_content_in_order(dates_by_duration)
  end

  def enter_search_term(term)
    visit root_path
    sleep(1)

    fill_in('search_term', with: term)
    find('#search_term').native.send_keys(:return)

    within('#title_box') do
      expect_content("Search: '#{term}'")
    end
  end
end
