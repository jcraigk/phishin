require "rails_helper"

RSpec.describe Admin::TaperNotesAiTracklist, :open_router do
  let(:filenames) { [ "d1t01.mp3", "d1t02.mp3" ] }
  let(:content) { { "d1t01.mp3" => "Llama", "d1t02.mp3" => "Foam", "other.mp3" => "Junk" }.to_json }
  let(:body) { chat_body(content) }

  def chat_body(text)
    { choices: [ { message: { content: text } } ] }.to_json
  end

  it "returns titles for the given filenames only" do
    allow(Typhoeus).to receive(:post).and_return(instance_double(Typhoeus::Response, success?: true, body:))
    expect(described_class.call(notes: "notes", filenames:))
      .to eq({ "d1t01.mp3" => "Llama", "d1t02.mp3" => "Foam" })
  end

  it "strips code fences from the model reply" do
    fenced = chat_body("```json\n#{content}\n```")
    allow(Typhoeus).to receive(:post).and_return(instance_double(Typhoeus::Response, success?: true, body: fenced))
    expect(described_class.call(notes: "notes", filenames:))
      .to eq({ "d1t01.mp3" => "Llama", "d1t02.mp3" => "Foam" })
  end

  it "returns an empty mapping on an API failure" do
    allow(Typhoeus).to receive(:post).and_return(instance_double(Typhoeus::Response, success?: false, body: ""))
    expect(described_class.call(notes: "notes", filenames:)).to eq({})
  end

  it "returns an empty mapping when the model replies with junk" do
    allow(Typhoeus).to receive(:post).and_return(
      instance_double(Typhoeus::Response, success?: true, body: chat_body("not json"))
    )
    expect(described_class.call(notes: "notes", filenames:)).to eq({})
  end
end
