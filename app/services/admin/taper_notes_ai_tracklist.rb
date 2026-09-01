module Admin::TaperNotesAiTracklist
  MODEL = "gpt-4o".freeze

  def self.call(notes:, filenames:)
    response = Typhoeus.post(
      "https://api.openai.com/v1/chat/completions",
      headers: {
        "Authorization" => "Bearer #{ENV.fetch('OPENAI_API_TOKEN')}",
        "Content-Type" => "application/json"
      },
      body: {
        model: MODEL,
        response_format: { type: "json_object" },
        messages: [ { role: "user", content: prompt(notes, filenames) } ]
      }.to_json
    )
    return {} unless response.code == 200
    content = JSON.parse(response.body).dig("choices", 0, "message", "content")
    mapping = JSON.parse(content)
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
      Omit any file the notes do not identify. No other keys, no commentary.

      TAPER NOTES:
      #{notes}

      FILES:
      #{filenames.join("\n")}
    PROMPT
  end
end
