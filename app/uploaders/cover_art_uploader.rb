class CoverArtUploader < PhishinUploader
  plugin :derivatives
  plugin :remote_url, max_size: 20*1024*1024 # 20 MB

  Attacher.derivatives do |original|
    vips = ImageProcessing::Vips.source(original)
    {
      medium: vips.resize_to_limit!(512, 512),
      small:  vips.resize_to_limit!(32, 32)
    }
  end

  def generate_location(io, record: nil, name: nil, derivative: nil, **)
    derivative_suffix = derivative ? "-#{derivative}" : ""
    "shows/cover_art/#{partition_path(record)}/#{record.id}#{derivative_suffix}.jpg"
  end
end
