class Id3AlbumArtChecker < ApplicationService
  param :track

  ID3_HEADER_SIZE = 10

  def call
    return :unreadable unless path && File.exist?(path)

    tag_size = id3v2_tag_size
    return :missing unless tag_size

    has_picture_frame?(tag_size) ? :present : :missing
  rescue SystemCallError
    :unreadable
  end

  private

  def path
    return unless track.mp3_audio.attached?
    @path ||= ActiveStorage::Blob.service.path_for(track.mp3_audio.blob.key)
  end

  # ID3v2 tags live at the head of the file. The 10-byte header stores the tag
  # body length as four "syncsafe" bytes (7 bits each), so we can read just the
  # tag rather than the whole MP3.
  def id3v2_tag_size
    header = File.binread(path, ID3_HEADER_SIZE)
    return unless header && header.bytesize == ID3_HEADER_SIZE
    return unless header[0, 3] == "ID3"

    bytes = header[6, 4].unpack("C4")
    return if bytes.any? { |byte| byte > 0x7f }

    (bytes[0] << 21) | (bytes[1] << 14) | (bytes[2] << 7) | bytes[3]
  end

  # APIC is the ID3v2.3/2.4 picture frame, PIC the ID3v2.2 equivalent.
  def has_picture_frame?(tag_size)
    tag = File.binread(path, tag_size, ID3_HEADER_SIZE).to_s
    tag.include?("APIC") || tag.include?("PIC\x00")
  end
end
