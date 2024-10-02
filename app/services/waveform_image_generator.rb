class WaveformImageGenerator
  attr_reader :track

  def initialize(track)
    @track = track
  end

  def call
    convert_mp3_to_wav
    generate_waveform_image
    track.update!(waveform_png: File.open(tmp_image))
    remove_temp_files
  end

  private

  def convert_mp3_to_wav
    audio_file_path = track.audio_file.to_io.path
    tmp_wav_path = tmp_wav
    Open3.capture3 \
      "ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i",
      audio_file_path, "-f", "wav", tmp_wav_path
  end

  def generate_waveform_image
    Waveform.generate(tmp_wav, tmp_image, options)
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
    File.delete(tmp_wav)
    File.delete(tmp_image)
  end

  def tmp_image
    @tmp_image = "#{base_dir}/#{track.id}.png"
  end

  def tmp_wav
    @tmp_wav = "#{base_dir}/#{track.id}.wav"
  end

  def base_dir
    @base_dir ||= "#{Rails.root}/tmp"
  end
end
