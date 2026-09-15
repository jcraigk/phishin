module Admin::TaperNotesAiTracklist
  MODEL = "claude-opus-5".freeze

  def self.call(notes:, filenames:)
    response = Typhoeus.post(
      "https://api.anthropic.com/v1/messages",
      headers: {
        "x-api-key" => ENV.fetch("ANTHROPIC_API_KEY"),
        "anthropic-version" => "2023-06-01",
        "Content-Type" => "application/json"
      },
      body: {
        model: MODEL,
        max_tokens: 4096,
        messages: [ { role: "user", content: prompt(notes, filenames) } ]
      }.to_json
    )
    return {} unless response.code == 200
    content = JSON.parse(response.body)["content"]
                  .find { |block| block["type"] == "text" }&.dig("text")
    return {} if content.blank?
    json_match = content.match(/```(?:json)?\s*(.*?)\s*```/m)
    mapping = JSON.parse(json_match ? json_match[1] : content)
    mapping.is_a?(Hash) ? mapping.slice(*filenames).select { |_k, v| v.is_a?(String) && v.present? } : {}
  rescue JSON::ParserError, KeyError
    {}
  end

  def self.prompt(notes, filenames)
    <<~PROMPT
      Below are the taper notes for a live concert recording, followed by a list
      of audio file names from that recording. Using only the taper notes, give
      each file the song title it contains. Reply with a JSON object whose keys
      are the file names exactly as given and whose values are the song titles.
      Omit any file the notes do not identify. No other keys, no commentary,
      and no code fences.

      TAPER NOTES:
      #{notes}

      FILES:
      #{filenames.join("\n")}
    PROMPT
  end
end
