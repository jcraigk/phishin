# frozen_string_literal: true
class Api::V1::ShowsController < Api::V1::ApiController
  caches_action :index, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL
  caches_action :show, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL
  caches_action :on_date, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL
  caches_action :on_day_of_year, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL

  def index
    show = Show.avail.includes(:venue)
    show = show.tagged_with(params[:tag]) if params[:tag]
    respond_with_success get_data_for(show)
  end

  def show
    return respond_with_success(show_on_date) if show_id_is_date?
    respond_with_success show_scope.find(params[:id])
  end

  def on_date
    respond_with_success show_on_date
  end

  def on_day_of_year
    return respond_with_404 unless month_and_day_from_params
    respond_with_success shows_on_day
  end

  def random
    respond_with_success random_show
  end

  private

  def month_param
    month_and_day_from_params&.first
  end

  def day_param
    month_and_day_from_params&.second
  end

  def month_and_day_from_params
    @month_and_day_from_params ||=
      if params[:day] =~
         /\A(january|february|march|april|may|june|july|august|september|october|november|december)-(\d{1,2})\z/i
        [Date::MONTHNAMES.index(Regexp.last_match[1].titleize), Regexp.last_match[2]]
      elsif params[:day] =~ /\A(\d{1,2})-(\d{1,2})\z/i
        [Regexp.last_match[1], Regexp.last_match[2]]
      end
  end

  def shows_on_day
    Show.avail
        .where('extract(month from date) = ?', month_param)
        .where('extract(day from date) = ?', day_param)
  end

  def show_scope
    Show.includes(:venue, { tracks: :songs }, :tags)
  end

  def show_id_is_date?
    params[:id] =~ /\d{4}-\d{2}-\d{2}/
  end

  def show_on_date
    @show_on_date ||= show_scope.find_by!(date: params[:id] || params[:date])
  end

  def random_show
    Show.includes(:venue, { tracks: :songs }, :tags)
        .avail
        .random
        .first
  end
end
