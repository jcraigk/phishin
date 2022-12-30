# frozen_string_literal: true

# Entire file copied from https://github.com/benalavi/waveform
# to fix issue with `File.exists?` removal in Ruby 3.2.0

require 'ruby-audio'
begin
  require 'oily_png'
rescue LoadError
  require 'chunky_png'
end

class Waveform
  DEFAULT_OPTIONS = {
    method: :peak,
    width: 1800,
    height: 280,
    background_color: '#666666',
    color: '#00ccff',
    force: false,
    logger: nil
  }.freeze
  TRANSPARENCY_MASK = '#00ff00'
  TRANSPARENCY_ALT = '#ffff00'

  attr_reader :source

  # Scope these under Waveform so you can catch the ones generated by just this
  # class.
  class RuntimeError < ::RuntimeError; end
  class ArgumentError < ::ArgumentError; end

  class << self
    # Generate a Waveform image at the given filename with the given options.
    #
    # Available options (all optional) are:
    #
    #   :method => The method used to read sample frames, available methods
    #     are peak and rms. peak is probably what you're used to seeing, it uses
    #     the maximum amplitude per sample to generate the waveform, so the
    #     waveform looks more dynamic. RMS gives a more fluid waveform and
    #     probably more accurately reflects what you hear, but isn't as
    #     pronounced (typically).
    #
    #     Can be :rms or :peak
    #     Default is :peak.
    #
    #   :width => The width (in pixels) of the final waveform image.
    #     Default is 1800.
    #
    #   :height => The height (in pixels) of the final waveform image.
    #     Default is 280.
    #
    #   :auto_width => msec per pixel. This will overwrite the width of the
    #     final waveform image depending on the length of the audio file.
    #     Example:
    #       100 => 1 pixel per 100 msec;
    #       a one minute audio file will result in a width of 600 pixels
    #
    #   :background_color => Hex code of the background color of the generated
    #     waveform image.
    #     Default is #666666 (gray).
    #
    #   :color => Hex code of the color to draw the waveform, or can pass
    #     :transparent to render the waveform transparent (use w/ a solid
    #     color background to achieve a "cutout" effect).
    #     Default is #00ccff (cyan-ish).
    #
    #   :force => Force generation of waveform, overwriting WAV or PNG file.
    #
    #   :logger => IOStream to log progress to.
    #
    # Example:
    #   Waveform.generate("Kickstart My Heart.wav", "Kickstart My Heart.png")
    #   Waveform.generate("Kickstart My Heart.wav", "Kickstart My Heart.png", :method => :rms)
    #   Waveform.generate \
    #     "Kickstart My Heart.wav", "Kickstart My Heart.png", color: "#ff00ff", logger: $stdout
    #

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def generate(source, filename, options = {})
      options = DEFAULT_OPTIONS.merge(options)

      unless source
        raise ArgumentError,
              'No source audio filename given, must be an existing sound file.'
      end
      raise ArgumentError, 'No destination filename given for waveform' unless filename
      raise "Source audio file '#{source}' not found." unless File.exist?(source)
      raise "Destination file #{filename} exists." if File.exist?(filename) && !options[:force]

      @log = Log.new(options[:logger])
      @log.start!

      if options[:auto_width]
        RubyAudio::Sound.open(source) do |audio|
          options[:width] = (audio.info.length * 1000 / options[:auto_width].to_i).ceil
        end
      end

      # Frames gives the amplitudes for each channel, for our waveform we're
      # saying the "visual" amplitude is the average of the amplitude across all
      # the channels. This might be a little weird w/ the "peak" method if the
      # frames are very wide (i.e. the image width is very small) -- I *think*
      # the larger the frames are, the more "peaky" the waveform should get,
      # perhaps to the point of inaccurately reflecting the actual sound.
      samples = frames(source, options[:width], options[:method]).collect do |frame|
        frame.sum(0.0) / frame.size
      end

      @log.timed("\nDrawing...") do
        # Don't remove the file even if force is true until we're sure the
        # source was readable
        if File.exist?(filename) && options[:force]
          @log.out("Output file #{filename} encountered. Removing.")
          File.unlink(filename)
        end

        image = draw samples, options
        image.save filename
      end

      @log.done!("Generated waveform '#{filename}'")
    end

    private

    # Returns a sampling of frames from the given RubyAudio::Sound using the
    # given method the sample size is determined by the given pixel width --
    # we want one sample frame per horizontal pixel.
    def frames(source, width, method = :peak)
      raise ArgumentError, "Unknown sampling method #{method}" unless %i[peak ms].include?(method)

      frames = []
      RubyAudio::Sound.open(source) do |audio|
        frames_read = 0
        frames_per_sample = (audio.info.frames.to_f / width).to_i
        sample = RubyAudio::Buffer.new('float', frames_per_sample, audio.info.channels)

        @log.timed("Sampling #{frames_per_sample} frames per sample: ") do
          while (frames_read = audio.read(sample)).positive?
            frames << send(method, sample, audio.info.channels)
            @log.out('.')
          end
        end
      end

      frames
    rescue RubyAudio::Error => e
      raise e unless e.message == 'File contains data in an unknown format.'
      raise Waveform::RuntimeError,
            "Source audio file #{source} could not be read by RubyAudio library"
    end

    def draw(samples, options)
      bg =
        if options[:background_color] == :transparent
          ChunkyPNG::Color::TRANSPARENT
        else
          options[:background_color]
        end
      image = ChunkyPNG::Image.new(options[:width], options[:height], bg)

      if options[:color] == :transparent
        # Have to do this little bit because it's possible the color we were
        # intending to use a transparency mask *is* the background color, and
        # then we'd end up wiping out the whole image.
        opt = if options[:background_color].downcase == TRANSPARENCY_MASK
                TRANSPARENCY_ALT
              else
                TRANSPARENCY_MASK
              end
        color = transparent = ChunkyPNG::Color.from_hex(opt)
      else
        color = ChunkyPNG::Color.from_hex(options[:color])
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      # Calling "zero" the middle of the waveform, like there's positive and
      # negative amplitude
      zero = options[:height] / 2.0

      samples.each_with_index do |sample, x|
        # Half the amplitude goes above zero, half below
        amplitude = sample * options[:height].to_f / 2.0
        # If you give ChunkyPNG floats for pixel positions all sorts of things
        # go haywire.
        image.line(x, (zero - amplitude).round, x, (zero + amplitude).round, color)
      end

      # Simple transparency masking, it just loops over every pixel and makes
      # ones which match the transparency mask color completely clear.
      if transparent
        (0..image.width - 1).each do |x|
          (0..image.height - 1).each do |y|
            image[x, y] = ChunkyPNG::Color.rgba(0, 0, 0, 0) if image[x, y] == transparent
          end
        end
      end

      image
    end

    # Returns an array of the peak of each channel for the given collection of
    # frames -- the peak is individual to the channel, and the returned collection
    # of peaks are not (necessarily) from the same frame(s).
    def peak(frames, channels = 1)
      peak_frame = []
      (0..channels - 1).each do |channel|
        peak_frame << channel_peak(frames, channel)
      end
      peak_frame
    end

    # Returns an array of rms values for the given frameset where each rms value is
    # the rms value for that channel.
    def rms(frames, channels = 1)
      rms_frame = []
      (0..channels - 1).each do |channel|
        rms_frame << channel_rms(frames, channel)
      end
      rms_frame
    end

    # Returns the peak voltage reached on the given channel in the given collection
    # of frames.
    #
    # TODO: Could lose some resolution and only sample every other frame, would
    # likely still generate the same waveform as the waveform is so comparitively
    # low resolution to the original input (in most cases), and would increase
    # the analyzation speed (maybe).
    def channel_peak(frames, channel = 0)
      peak = 0.0
      frames.each do |frame|
        next if frame.nil?
        frame = Array(frame)
        peak = frame[channel].abs if frame[channel].abs > peak
      end
      peak
    end

    # Returns the rms value across the given collection of frames for the given
    # channel.
    def channel_rms(frames, channel = 0)
      Math.sqrt(
        frames.inject(0.0) do |sum, frame|
          sum + (frame ? Array(frame)[channel]**2 : 0)
        end / frames.size
      )
    end
  end
end

class Waveform
  # A simple class for logging + benchmarking, nice to have good feedback on a
  # long batch operation.
  #
  # There's probably 10,000,000 other bechmarking classes, but writing this was
  # easier than using Google.
  class Log
    attr_accessor :io

    def initialize(io = $stdout)
      @io = io
    end

    # Prints the given message to the log
    def out(msg)
      io&.print(msg)
    end

    # Prints the given message to the log followed by the most recent benchmark
    # (note that it calls .end! which will stop the benchmark)
    def done!(msg = '')
      out "#{msg} (#{end!}s)\n"
    end

    # Starts a new benchmark clock and returns the index of the new clock.
    #
    # If .start! is called again before .end! then the time returned will be
    # the elapsed time from the next call to start!, and calling .end! again
    # will return the time from *this* call to start! (that is, the clocks are
    # LIFO)
    def start!
      (@benchmarks ||= []) << Time.zone.now
      @current = @benchmarks.size - 1
    end

    # Returns the elapsed time from the most recently started benchmark clock
    # and ends the benchmark, so that a subsequent call to .end! will return
    # the elapsed time from the previously started benchmark clock.
    def end!
      elapsed = (Time.zone.now - @benchmarks[@current])
      @current -= 1
      elapsed
    end

    # Returns the elapsed time from the benchmark clock w/ the given index (as
    # returned from when .start! was called).
    def time?(index)
      Time.zone.now - @benchmarks[index]
    end

    # Benchmarks the given block, printing out the given message first (if
    # given).
    def timed(message = nil)
      start!
      out(message) if message
      yield
      done!
    end
  end
end
