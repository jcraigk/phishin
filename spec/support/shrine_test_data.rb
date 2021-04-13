# frozen_string_literal: true
module ShrineTestData
  module_function

  def attachment_data
    attacher = Shrine::Attacher.new
    attacher.set(uploaded_file)
    attacher.column_data
  end

  def uploaded_file
    file = File.open("#{Rails.root}/spec/fixtures/test.mp3", binmode: true)

    # for performance we skip metadata extraction and assign test metadata
    uploaded_file = Shrine.upload(file, :store, metadata: false)
    uploaded_file.metadata.merge!(
      size: File.size(file.path),
      mime_type: 'audio/mpeg',
      filename: 'test.mp3'
    )

    uploaded_file
  end
end
