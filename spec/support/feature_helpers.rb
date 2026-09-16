module FeatureHelpers
  def sign_in(user)
    visit "/login"
    fill_in "email", with: user.email
    fill_in "password", with: "password"
    click_on "Login"

    # Wait for successful login by checking that we've navigated away from /login
    # and that the page no longer has the login form
    expect(page).to have_no_current_path("/login", wait: 10)
    expect(page).to have_no_button("Login", wait: 10)

    # Additional check: wait for JWT to be present in localStorage
    # This ensures the authentication flow has completed
    jwt = page.evaluate_script("localStorage.getItem('jwt')")
    expect(jwt).to be_present
  end

  # Signs in without submitting the login form. After a password form submits,
  # headless Chrome stops delivering synthetic mouse input after the next click
  # for the rest of the example, so specs that click more than once after
  # signing in should use this instead of sign_in.
  def sign_in_via_jwt(user)
    visit "/"
    page.execute_script(<<~JS)
      localStorage.setItem("jwt", #{UserJwtService.call(user).to_json});
      localStorage.setItem("username", #{user.username.to_json});
      localStorage.setItem("email", #{user.email.to_json});
      localStorage.setItem("usernameUpdatedAt", "");
      localStorage.setItem("admin", #{user.admin?.to_json});
    JS
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
