require "rails_helper"

RSpec.describe OpenRouter, :open_router do
  def stub_post(body, success: true)
    allow(Typhoeus).to receive(:post)
      .and_return(instance_double(Typhoeus::Response, success?: success, body: body.to_json))
  end

  describe ".chat" do
    let(:body) do
      {
        choices: [ { message: { role: "assistant", content: "Hi!" } } ],
        usage: { prompt_tokens: 13, completion_tokens: 5, cost: 0.000038 }
      }
    end

    it "returns the reply text" do
      stub_post(body)
      expect(described_class.chat(model: "m", prompt: "p").text).to eq("Hi!")
    end

    it "returns token counts and cost" do
      stub_post(body)
      result = described_class.chat(model: "m", prompt: "p")
      expect(result).to have_attributes(input_tokens: 13, output_tokens: 5, cost: 0.000038)
    end

    it "posts to the chat completions endpoint with a bearer key" do
      stub_post(body)
      described_class.chat(model: "m", prompt: "p")
      expect(Typhoeus).to have_received(:post) do |url, options|
        expect(url).to eq("https://openrouter.ai/api/v1/chat/completions")
        expect(options[:headers]["Authorization"]).to eq("Bearer #{OpenRouterEnv::PLACEHOLDER_KEY}")
      end
    end

    it "sends the system prompt as a system message" do
      stub_post(body)
      described_class.chat(model: "m", prompt: "p", system: "be terse")
      expect(Typhoeus).to have_received(:post) do |_url, options|
        expect(JSON.parse(options[:body])["messages"]).to eq(
          [ { "role" => "system", "content" => "be terse" }, { "role" => "user", "content" => "p" } ]
        )
      end
    end

    it "raises on a failed request" do
      stub_post({ error: "boom" }, success: false)
      expect { described_class.chat(model: "m", prompt: "p") }
        .to raise_error(OpenRouter::Error, /boom/)
    end

    it "raises when the reply has no text" do
      stub_post({ choices: [ { message: { content: "" } } ] })
      expect { described_class.chat(model: "m", prompt: "p") }
        .to raise_error(OpenRouter::Error, /No text/)
    end
  end

  describe ".image" do
    let(:body) { { data: [ { b64_json: "aGk=", media_type: "image/png" } ], usage: { cost: 0.04 } } }

    it "returns the base64 image and cost" do
      stub_post(body)
      expect(described_class.image(model: "m", prompt: "p")).to have_attributes(b64: "aGk=", cost: 0.04)
    end

    it "posts to the images endpoint" do
      stub_post(body)
      described_class.image(model: "m", prompt: "p")
      expect(Typhoeus).to have_received(:post).with("https://openrouter.ai/api/v1/images", any_args)
    end

    it "omits input references when there is no source image" do
      stub_post(body)
      described_class.image(model: "m", prompt: "p")
      expect(Typhoeus).to have_received(:post) do |_url, options|
        expect(JSON.parse(options[:body])).not_to have_key("input_references")
      end
    end

    it "passes the source image as an input reference" do
      stub_post(body)
      described_class.image(model: "m", prompt: "p", source_url: "data:image/png;base64,xx")
      expect(Typhoeus).to have_received(:post) do |_url, options|
        expect(JSON.parse(options[:body])["input_references"]).to eq(
          [ { "type" => "image_url", "image_url" => { "url" => "data:image/png;base64,xx" } } ]
        )
      end
    end

    it "raises when no image comes back" do
      stub_post({ data: [] })
      expect { described_class.image(model: "m", prompt: "p") }
        .to raise_error(OpenRouter::Error, /No image/)
    end

    it "reports error bodies with non-ascii bytes" do
      allow(Typhoeus).to receive(:post)
        .and_return(instance_double(Typhoeus::Response, success?: false, body: "child’s".b))
      expect { described_class.image(model: "m", prompt: "p") }
        .to raise_error(OpenRouter::Error, /child’s/)
    end
  end

  describe ".extract_json" do
    it "parses bare JSON" do
      expect(described_class.extract_json('{"a":1}')).to eq("a" => 1)
    end

    it "strips code fences" do
      expect(described_class.extract_json("```json\n{\"a\":1}\n```")).to eq("a" => 1)
    end

    it "symbolizes names on request" do
      expect(described_class.extract_json('{"a":1}', symbolize_names: true)).to eq(a: 1)
    end
  end
end
