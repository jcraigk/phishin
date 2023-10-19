class WaveformImageGenerator
  attr_reader :track, :data

  def initialize(track)
    @track = track
  end

  def call
    convert_mp3_to_wav
    extract_waveform_data
    generate_waveform_image
    track.update!(
      waveform_max: data.max,
      waveform_image: File.open(tmp_image)
    )
    remove_temp_files
  end

  private

  def extract_waveform_data
    @data = Waveformjson.generate(tmp_wav, options)
  end

  def convert_mp3_to_wav
    `ffmpeg -y -hide_banner -loglevel error -i #{track.audio_file.to_io.path} -f wav #{tmp_wav}`
  end

  def generate_waveform_image
    Waveform.generate(tmp_wav, tmp_image, options)
  end

  def options
    {
      method: :peak,
      width: 500,
      height: 70,
      color: :transparent,
      background_color: '#f2f3f5',
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
