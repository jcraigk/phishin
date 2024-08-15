Rails.application.config.filter_parameters += %i[
  password secret token crypt salt
]
