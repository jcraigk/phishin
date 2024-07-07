class ReportsController < ApplicationController
  caches_action_params :missing_content

  def missing_content
    @kdates = notable_known_dates
    @incomplete_dates = incomplete_dates
    render_view
  end

  private

  def complete_dates
    Show.published.where(incomplete: false).all.map(&:date)
  end

  def incomplete_dates
    Show.published.where(incomplete: true).all.map(&:date)
  end

  def notable_known_dates
    KnownDate.where.not(date: complete_dates)
             .where(date: ...Time.zone.today)
             .order(date: :desc)
  end
end
