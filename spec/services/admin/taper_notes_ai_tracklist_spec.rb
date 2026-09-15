require "rails_helper"

RSpec.describe Admin::TaperNotesAiTracklist do
  let(:filenames) { [ "d1t01.mp3", "d1t02.mp3" ] }
  let(:content) { { "d1t01.mp3" => "Llama", "d1t02.mp3" => "Foam", "other.mp3" => "Junk" }.to_json }
  let(:body) { { content: [ { type: "text", text: content } ] }.to_json }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ANTHROPIC_API_KEY").and_return("test-token")
  end

  it "returns titles for the given filenames only" do
    allow(Typhoeus).to receive(:post).and_return(instance_double(Typhoeus::Response, code: 200, body:))
    expect(described_class.call(notes: "notes", filenames:))
      .to eq({ "d1t01.mp3" => "Llama", "d1t02.mp3" => "Foam" })
  end

  it "strips code fences from the model reply" do
    fenced = { content: [ { type: "text", text: "```json\n#{content}\n```" } ] }.to_json
    allow(Typhoeus).to receive(:post).and_return(instance_double(Typhoeus::Response, code: 200, body: fenced))
    expect(described_class.call(notes: "notes", filenames:))
      .to eq({ "d1t01.mp3" => "Llama", "d1t02.mp3" => "Foam" })
  end

  it "returns an empty mapping on an API failure" do
    allow(Typhoeus).to receive(:post).and_return(instance_double(Typhoeus::Response, code: 500, body: ""))
    expect(described_class.call(notes: "notes", filenames:)).to eq({})
  end

  it "returns an empty mapping when the model replies with junk" do
    allow(Typhoeus).to receive(:post).and_return(
      instance_double(Typhoeus::Response, code: 200, body: { content: [ { type: "text", text: "not json" } ] }.to_json)
    )
    expect(described_class.call(notes: "notes", filenames:)).to eq({})
  end
end
