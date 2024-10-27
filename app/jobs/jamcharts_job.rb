class JamchartsJob
  include Sidekiq::Job

  def perform
    JamchartsImporter.new(api_key).call
  end

  private

  def api_key
    ENV.fetch("PNET_API_KEY")
  end
end
