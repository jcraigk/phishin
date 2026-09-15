module Mp3Bytes
  def mp3_frame_sync?(bytes)
    body = bytes.dup.force_encoding(Encoding::BINARY)
    body = body.byteslice(id3v2_size(body)..) || "" if body.start_with?("ID3".b)
    body.bytesize >= 2 && body.getbyte(0) == 0xFF && (body.getbyte(1) & 0xE0) == 0xE0
  end

  def id3v2_size(bytes)
    10 + bytes.byteslice(6, 4).unpack("C4").reduce(0) { |sum, byte| (sum << 7) | (byte & 0x7F) }
  end
end

RSpec.configure { |config| config.include Mp3Bytes }
