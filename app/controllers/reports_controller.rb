# frozen_string_literal: true
class ReportsController < ApplicationController
  caches_action_params :missing_content

  def missing_content
    @kdates = notable_known_dates
    @incomplete_dates = incomplete_dates
    render_xhr_without_layout
  end

  private

  def complete_dates
    Show.published.where(incomplete: false).all.map(&:date)
  end

  def incomplete_dates
    Show.published.where(incomplete: true).all.map(&:date)
  end

  def notable_known_dates
    KnownDate.where.not(date: complete_dates).order(date: :desc)
  end
end
