class WidgetCompiler
  SOURCE_DIR = Rails.root.join("app", "mcp", "widgets")
  OUTPUT_DIR = Rails.root.join("public", "mcp-widgets")
  PARTIALS_DIR = SOURCE_DIR.join("partials")

  class << self
    def compile_all(force: false)
      ensure_output_dir
      widget_sources.each { |source| compile_widget(Pathname.new(source), force:) }
    end

    def compile_if_stale(widget_name)
      source = Pathname.new(SOURCE_DIR.join("#{widget_name}.html.erb"))
      return false unless source.exist?

      output = Pathname.new(OUTPUT_DIR.join("#{widget_name}.html"))
      return false if output.exist? && !stale?(source, output)

      compile_widget(source, force: true)
      true
    end

    def stale?(source, output)
      return true unless output.exist?

      output_mtime = output.mtime
      return true if source.mtime > output_mtime

      partial_files.any? { |p| p.mtime > output_mtime }
    end

    def compile_widget(source_path, force: false)
      widget_name = File.basename(source_path, ".html.erb")
      output_path = OUTPUT_DIR.join("#{widget_name}.html")

      return if !force && output_path.exist? && !stale?(source_path, output_path)

      template = File.read(source_path)
      context = WidgetContext.new
      html = context.render(template, source_path)

      File.write(output_path, html)
      Rails.logger.info "[WidgetCompiler] Compiled #{widget_name}.html"
      output_path
    end

    def widget_sources
      Dir.glob(SOURCE_DIR.join("*.html.erb"))
    end

    def partial_files
      Dir.glob(PARTIALS_DIR.join("*.erb")).map { |p| Pathname.new(p) }
    end

    private

    def ensure_output_dir
      FileUtils.mkdir_p(OUTPUT_DIR)
    end
  end

  class WidgetContext
    def initialize
      @partials_dir = PARTIALS_DIR
    end

    def render(template, source_path)
      erb = ERB.new(template, trim_mode: "-")
      erb.filename = source_path.to_s
      erb.result(binding)
    end

    def partial(name)
      partial_path = @partials_dir.join("_#{name}.html.erb")
      raise "Partial not found: #{name}" unless partial_path.exist?

      template = File.read(partial_path)
      erb = ERB.new(template, trim_mode: "-")
      erb.filename = partial_path.to_s
      erb.result(binding)
    end

    def asset_host_placeholder
      "{{WIDGET_ASSET_HOST}}"
    end

    def gapless5_script
      path = Rails.root.join("node_modules", "@regosen", "gapless-5", "gapless5.js")
      script = File.read(path)
      # Remove iOS silent audio hack that triggers CSP violations - we handle user interaction ourselves
      script.gsub(
        /const silenceWavData = .*?stubAudio\.load\(\);/m,
        "// iOS silent audio hack removed for CSP compatibility"
      )
    end
  end
end
