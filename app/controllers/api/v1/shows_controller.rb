class Api::V1::ShowsController < Api::V1::ApiController
  caches_action_params :index
  caches_action_params :show
  caches_action_params :on_date, %i[date]
  caches_action_params :on_day_of_year, %i[day]

  def index
    shows = Show.published.with_audio.includes(:venue, :tags, tracks: %i[songs tags])
    shows = shows.tagged_with(params[:tag]) if params[:tag]
    respond_with_success get_data_for(shows)
  end

  def show
    return respond_with_success(show_on_date) if show_id_is_date?
    respond_with_success show_scope.find(params[:id])
  end

  def on_date
    respond_with_success show_on_date
  end

  def on_day_of_year
    return respond_with_not_found unless month_and_day_from_params
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
    @month_and_day_from_params ||= month_day_from_longform || month_day_from_shortform
  end

  def month_day_from_longform
    return unless params[:day] =~ long_form_regex
    [ month_num_from_name(Regexp.last_match[1]), Regexp.last_match[2] ]
  end

  def month_day_from_shortform
    return unless params[:day] =~ short_form_regex
    [ Regexp.last_match[1], Regexp.last_match[2] ]
  end

  def month_num_from_name(name)
    Date::MONTHNAMES.index(name.titleize)
  end

  def long_form_regex
    /
      \A
      (january|february|march|april|may|june|july|august|september|october|november|december)
      -
      (\d{1,2})
      \z
    /xi
  end

  def short_form_regex
    /\A(\d{1,2})-(\d{1,2})\z/i
  end

  def shows_on_day
    show_scope.where("extract(month from date) = ?", month_param)
              .where("extract(day from date) = ?", day_param)
  end

  def show_scope
    Show.published.with_audio.includes(:venue, :tags, tracks: %i[songs tags])
  end

  def show_id_is_date?
    params[:id] =~ /\d{4}-\d{1,2}-\d{1,2}/
  end

  def show_on_date
    @show_on_date ||= show_scope.find_by!(date: params[:id] || params[:date])
  end

  def random_show
    show_scope.random.first
  end
end
