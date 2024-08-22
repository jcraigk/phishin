class ApplicationMailer < ActionMailer::Base
  default from: App.auth_email_from
end
