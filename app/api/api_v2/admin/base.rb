class ApiV2::Admin::Base < ApiV2::Base
  # Grape settings (helpers, before blocks) come from the mounting API, not from a
  # superclass, so declaring them here does not reach subclasses. Each admin endpoint
  # class must declare `helpers ApiV2::Helpers::AdminHelper` and
  # `before { authenticate_admin! }` in its own body, directly inside the class
  # rather than inside a `namespace`.
end
