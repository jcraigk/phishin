require "rails_helper"

RSpec.describe AttachmentBackupJob do
  let(:existing_keys) { Set["ab/cd/abcdef"] }

  before do
    allow(Backup::ListingService).to receive(:call).and_return(existing_keys)
    allow(Backup::AttachmentService).to receive(:call)
  end

  it "backs up every configured attachment using one S3 listing" do
    described_class.new.perform

    Rails.configuration.attachment_backup[:attachments].each do |config|
      expect(Backup::AttachmentService)
        .to have_received(:call).with(config[:model], config[:attachment], existing_keys)
    end
    expect(Backup::ListingService).to have_received(:call).once
  end

  context "when the S3 listing comes back empty" do
    let(:existing_keys) { Set.new }

    it "raises without uploading anything" do
      expect { described_class.new.perform }.to raise_error(/S3 listing returned no keys/)
      expect(Backup::AttachmentService).not_to have_received(:call)
    end
  end
end
