class JamchartsJob
  include Sidekiq::Job

  def perform
    JamchartsImporter.call(api_key)
  end

  private

  def api_key
    ENV.fetch("PNET_API_KEY")
  end
end
