# https://github.com/shakacode/react_on_rails/blob/master/docs/guides/configuration.md

ReactOnRails.configure do |config|
  config.build_test_command = "RAILS_ENV=test bin/shakapacker"
  config.server_bundle_js_file = "server-bundle.js"
  config.auto_load_bundle = false
  config.same_bundle_for_client_and_server = true
end
