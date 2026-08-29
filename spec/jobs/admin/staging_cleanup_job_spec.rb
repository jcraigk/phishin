require "rails_helper"

RSpec.describe Admin::StagingCleanupJob do
  let(:staging) { create(:show, date: "2024-07-19") }
  let(:committed) { create(:show, date: "2024-07-20") }

  before do
    create(:staged_source, show: staging)
    [ staging, committed ].each { Admin::StagingDir.new(it).reset! }
    FileUtils.mkdir_p(Admin::StagingDir::ROOT.join("1999-12-31"))
  end

  after { [ staging, committed ].each { Admin::StagingDir.new(it).remove! } }

  it "removes directories whose show has no staged sources, and unknown dates" do
    described_class.new.perform
    expect(Dir.exist?(Admin::StagingDir.new(staging).root)).to be(true)
    expect(Dir.exist?(Admin::StagingDir.new(committed).root)).to be(false)
    expect(Dir.exist?(Admin::StagingDir::ROOT.join("1999-12-31"))).to be(false)
  end
end
