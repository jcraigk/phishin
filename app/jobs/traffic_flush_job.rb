class TrafficFlushJob
  include Sidekiq::Job

  sidekiq_options retry: 1

  def perform
    TrafficBuffer.flush!
  end
end
