module FeatureHelpers
  def sign_in(user)
    visit "/login"
    fill_in "email", with: user.email
    fill_in "password", with: "password"
    click_on "Login"
  end

  def format_duration_show(milliseconds)
    total_minutes = (milliseconds / 60000).floor
    hours = (total_minutes / 60).floor
    minutes = total_minutes % 60

    if hours > 0
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
  end

  def format_date_long(date_string)
    Date.parse(date_string.to_s).strftime("%B %-d, %Y")
  end
end
