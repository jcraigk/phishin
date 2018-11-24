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
end
