namespace :widgets do
  desc "Compile all widget templates from app/mcp/widgets/ to public/mcp-widgets/"
  task compile: :environment do
    puts "Compiling widgets..."
    WidgetCompiler.compile_all(force: ENV["FORCE"].present?)
    puts "Done! Compiled #{WidgetCompiler.widget_sources.count} widget(s)"
  end

  desc "Force recompile all widgets (ignores staleness check)"
  task recompile: :environment do
    ENV["FORCE"] = "1"
    Rake::Task["widgets:compile"].invoke
  end

  desc "Check if any widgets need recompilation"
  task check: :environment do
    stale_widgets = WidgetCompiler.widget_sources.select do |source|
      widget_name = File.basename(source, ".html.erb")
      output = WidgetCompiler::OUTPUT_DIR.join("#{widget_name}.html")
      WidgetCompiler.stale?(Pathname.new(source), output)
    end

    if stale_widgets.any?
      puts "Stale widgets found:"
      stale_widgets.each { |s| puts "  - #{File.basename(s, '.html.erb')}" }
      exit 1
    else
      puts "All widgets are up to date"
    end
  end
end
