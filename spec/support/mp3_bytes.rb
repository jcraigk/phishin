# Asserts that a blob of bytes is actually decodable mp3, without assuming which
# encoder produced it.
#
# The renders go through lame (see LameEncoding), which writes a bare mp3: the
# first frame carries the LAME/Xing header and there is no ID3v2 tag at all.
# ffmpeg's mp3 muxer does write one. Both are valid, so a spec that checks for
# "ID3" is really checking which encoder ran, not whether the audio is readable.
#
# Every mp3 frame starts with eleven set sync bits, so the first two bytes are
# 0xFF followed by a byte whose top three bits are set. An ID3v2 tag is skipped
# when present so the same matcher works either way.
module Mp3Bytes
  def mp3_frame_sync?(bytes)
    body = bytes.dup.force_encoding(Encoding::BINARY)
    body = body.byteslice(id3v2_size(body)..) || "" if body.start_with?("ID3".b)
    body.bytesize >= 2 && body.getbyte(0) == 0xFF && (body.getbyte(1) & 0xE0) == 0xE0
  end

  # An ID3v2 header is ten bytes, and its length is stored in the last four as
  # syncsafe integers - seven bits per byte, high bit always clear.
  def id3v2_size(bytes)
    10 + bytes.byteslice(6, 4).unpack("C4").reduce(0) { |sum, byte| (sum << 7) | (byte & 0x7F) }
  end
end

RSpec.configure { |config| config.include Mp3Bytes }
