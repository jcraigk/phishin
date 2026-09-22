module OpenRouter
  BASE_URL = "https://openrouter.ai/api/v1".freeze
  Error = Class.new(StandardError)

  ChatResult = Struct.new(:text, :input_tokens, :output_tokens, :cost, keyword_init: true)
  ImageResult = Struct.new(:b64, :cost, keyword_init: true)

  def self.chat(model:, prompt:, system: nil, max_tokens: 4096)
    messages = []
    messages << { role: "system", content: system } if system.present?
    messages << { role: "user", content: prompt }
    result = request("chat/completions", model:, max_tokens:, messages:, usage: { include: true })
    text = result.dig("choices", 0, "message", "content")
    raise Error, "No text in OpenRouter response: #{result.to_json.truncate(500)}" if text.blank?
    usage = result["usage"] || {}
    ChatResult.new(
      text:,
      input_tokens: usage["prompt_tokens"].to_i,
      output_tokens: usage["completion_tokens"].to_i,
      cost: usage["cost"]&.to_f
    )
  end

  def self.image(model:, prompt:, source_url: nil)
    body = {
      model:, prompt:, n: 1, aspect_ratio: "1:1", resolution: "1K", quality: "high", output_format: "png"
    }
    body[:input_references] = [ { type: "image_url", image_url: { url: source_url } } ] if source_url
    result = request("images", **body)
    b64 = result.dig("data", 0, "b64_json")
    raise Error, "No image in OpenRouter response" if b64.blank?
    ImageResult.new(b64:, cost: result.dig("usage", "cost")&.to_f)
  end

  def self.extract_json(text, symbolize_names: false)
    match = text.match(/```(?:json)?\s*(.*?)\s*```/m)
    JSON.parse(match ? match[1] : text, symbolize_names:)
  end

  def self.request(path, **body)
    response = Typhoeus.post(
      "#{BASE_URL}/#{path}",
      headers: {
        "Authorization" => "Bearer #{ENV.fetch("OPENROUTER_API_KEY")}",
        "Content-Type" => "application/json"
      },
      body: body.to_json
    )
    raise Error, "OpenRouter #{path} error: #{safe_body(response)}" unless response.success?
    JSON.parse(safe_body(response))
  end

  def self.safe_body(response)
    response.body.to_s.dup.force_encoding(Encoding::UTF_8).scrub
  end
end
