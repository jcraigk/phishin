class BaseService
  extend Dry::Initializer

  def self.call(...)
    new(...).call
  end
end
