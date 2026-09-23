class CrawlableContentService < ApplicationService
  param :path

  def call
    return unless show_path?

    show = Show.published.includes(:venue, :tour, :tracks).find_by(date: segments[0])
    { partial: "crawlable/show", locals: { show: } } if show
  end

  private

  def show_path?
    segments.one? && segments[0].match?(/\A\d{4}-\d{2}-\d{2}\z/)
  end

  def segments
    @segments ||= path.split("/").reject(&:empty?)
  end
end
