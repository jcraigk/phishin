class WaveformImageService < BaseService
  param :track

  def call
    create_temp_mp3_file
    convert_mp3_to_wav
    generate_waveform_image
    attach_waveform_image
    remove_temp_files
  end

  private

  def create_temp_mp3_file
    @temp_mp3 = Tempfile.new([ "track_#{track.id}", ".mp3" ])
    @temp_mp3.binmode
    @temp_mp3.write(track.mp3_audio.download)
    @temp_mp3.rewind
  end

  def convert_mp3_to_wav
    tmp_wav_path = tmp_wav
    Open3.capture3 \
      "ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i",
      @temp_mp3.path, "-f", "wav", tmp_wav_path
  end

  def generate_waveform_image
    Waveform.generate(tmp_wav, tmp_image, options)
  end

  def attach_waveform_image
    track.png_waveform.attach \
      io: File.open(tmp_image),
      filename: "#{track.id}.png",
      content_type: "image/png"
  end

  def options
    {
      method: :peak,
      width: 1100,
      height: 70,
      color: "#999999",
      background_color: :transparent,
      force: true
    }
  end

  def remove_temp_files
    File.delete(tmp_wav) if File.exist?(tmp_wav)
    File.delete(tmp_image) if File.exist?(tmp_image)
    @temp_mp3.close! if @temp_mp3
  end

  def tmp_image
    "#{base_dir}/#{track.id}.png"
  end

  def tmp_wav
    "#{base_dir}/#{track.id}.wav"
  end

  def base_dir
    @base_dir ||= "#{Rails.root}/tmp"
  end
end
