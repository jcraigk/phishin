# frozen_string_literal: true
require 'marcel'

module ShrineTestData
  module_function

  def attachment_data(filename)
    attacher = Shrine::Attacher.new
    attacher.set(fixture_file(filename))
    attacher.column_data
  end

  def fixture_file(filename)
    file = File.open("#{Rails.root}/spec/fixtures/#{filename}", binmode: true)

    # For performance we skip metadata extraction and assign test metadata
    uploaded_file = Shrine.upload(file, :store, metadata: false)
    uploaded_file.metadata.merge!(
      size: File.size(file.path),
      mime_type: Marcel::MimeType.for(Pathname.new(file)),
      filename: filename
    )
    uploaded_file
  end
end
