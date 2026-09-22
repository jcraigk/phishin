module Admin::TaperNotesAiTracklist
  MODEL = "anthropic/claude-opus-5".freeze

  def self.call(notes:, filenames:)
    text = OpenRouter.chat(model: MODEL, prompt: prompt(notes, filenames)).text
    mapping = OpenRouter.extract_json(text)
    mapping.is_a?(Hash) ? mapping.slice(*filenames).select { |_k, v| v.is_a?(String) && v.present? } : {}
  rescue OpenRouter::Error, JSON::ParserError, KeyError
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
