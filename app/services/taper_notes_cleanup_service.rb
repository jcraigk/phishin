class TaperNotesCleanupService < BaseService
  param :show

  BASE_PROMPT = <<~TXT
    I'm going to give you a text document that represents taper notes of an audio engineer who recorded a live rock concert by the band Phish. I want you to clean these notes up but in very specific ways. In fact I want the exact character for character content to be provided unless I explicitly state that you should remove it.

    First, look at the end or near the end of the document to find hashes to verify audio file contents that look like this:

    "ph1989-10-20d2t08.flac:4f01ae48418f111734de47ee2042a1ee
    ph1989-10-20d1t02.flac:53c113df943113fc5a98986ecb73f94e
    ph1989-10-20d1t03.flac:f355a8e8c2ad1dc1e25037464412f349"

    Here is another example:

    "3:15.50 34515644 B --- -- ---xx flac 0.4700 ph1987-09-21d1t01.flac
    3:25.05 36173804 B --- -- ---xx flac 0.5743 ph1987-09-21d1t02.flac"

    To help identify these, look for a list that contains no English words, and will often contain "flac" referring to a FLAC file. If you don't see these lines in the document, good. If you do, remove them from the document.

    If you remove these lines, remove any other headers or extra characters that are now at the end of the document. Here is an example:

    "---------------------------------------------------------------------------------------------------------

    SHNtool len mode output:

    length expanded size cdr WAVE problems fmt ratio filename"

    You should remove successive blank lines if they exceed 3. Lines that contain invisible characters only count as blank lines.

    At the end of the document, you should remove any blank lines.

    After cleaning the document, you should respond with only the remaining text of the document, character for character as it was given to you. Do not add any additional content or formatting.
  TXT

  def call
    cleanup_taper_notes
  end

  private

  def cleanup_taper_notes
    show.update!(taper_notes: chatgpt_response)
  end

  def chatgpt_prompt
    return @chatgpt_prompt if defined?(@chatgpt_prompt)
    txt = BASE_PROMPT.dup
    txt += "\n\nHere is the document:\n\n"
    txt += show.taper_notes
    @chatgpt_prompt = txt
  end

  def chatgpt_response
    return @chatgpt_response if defined?(@chatgpt_response)

    response = Typhoeus.post(
      "https://api.openai.com/v1/chat/completions",
      headers: {
        "Authorization" => "Bearer #{openai_api_token}",
        "Content-Type" => "application/json"
      },
      body: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: "You are an expert in cleaning up text documents." },
          { role: "user", content: chatgpt_prompt }
        ]
      }.to_json
    )

    if response.success?
      @chatgpt_response = JSON[response.body]["choices"].first["message"]["content"]
    else
      raise "Failed to get response from ChatGPT: #{response.body}"
    end

    @chatgpt_response
  end

  def openai_api_token
    @openai_api_token ||= ENV.fetch("OPENAI_API_TOKEN")
  end
end
