RSpec.configure do |config|
  config.include Sorcery::TestHelpers::Rails
end

module Sorcery
  module TestHelpers
    module Rails
      def sign_in(user)
        visit login_path
        fill_in 'email', with: user.email
        fill_in 'password', with: 'password'
        click_on I18n.t('auth.login')
      end
    end
  end
end
