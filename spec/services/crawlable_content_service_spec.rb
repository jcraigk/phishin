require "rails_helper"

RSpec.describe CrawlableContentService do
  subject(:content) { described_class.call(path) }

  context "when the path is a published show" do
    let!(:show) { create(:show, date: "2024-01-01") }
    let(:path) { "/2024-01-01" }

    it "returns the show partial with the show" do
      expect(content).to eq(partial: "crawlable/show", locals: { show: })
    end
  end

  context "when the show is unpublished" do
    let(:path) { "/2024-01-01" }

    before { create(:show, date: "2024-01-01", published: false) }

    it "returns nil" do
      expect(content).to be_nil
    end
  end

  context "when the date is invalid" do
    let(:path) { "/2024-13-45" }

    it "returns nil" do
      expect(content).to be_nil
    end
  end

  context "when the path is a track page" do
    let(:path) { "/2024-01-01/tweezer" }

    before { create(:show, date: "2024-01-01") }

    it "returns nil" do
      expect(content).to be_nil
    end
  end
end
