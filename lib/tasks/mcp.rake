namespace :mcp do
  desc "Display MCP tool descriptions per client with read/write indicators and widget info"
  task tools: :environment do
    cyan = "\e[36m"
    dim = "\e[2m"
    green = "\e[32m"
    yellow = "\e[33m"
    reset = "\e[0m"

    box_width = 76
    text_width = box_width - 4

    wrap_text = ->(text, width) {
      words = text.split
      lines = []
      current_line = ""
      words.each do |word|
        if current_line.empty?
          current_line = word
        elsif (current_line.length + 1 + word.length) <= width
          current_line += " #{word}"
        else
          lines << current_line
          current_line = word
        end
      end
      lines << current_line unless current_line.empty?
      lines
    }

    clients = Server::VALID_CLIENTS
    base_tools = ToolBuilder.base_tools

    clients.each do |client|
      puts "\n#{"═" * box_width}"
      puts "  📡 #{client.to_s.upcase} CLIENT"
      puts "#{"═" * box_width}\n\n"

      base_tools.each do |tool_class|
        tool_name = tool_class.name_value
        description = Descriptions.for(tool_name, client)
        annotations = tool_class.try(:annotations_value)

        read_only = annotations&.read_only_hint
        has_widget = client == :openai && tool_class.respond_to?(:openai_meta) && tool_class.openai_meta.present?

        mode_emoji = read_only ? "📖" : "✏️"
        mode_label = read_only ? "read" : "write"
        mode_color = read_only ? green : yellow
        widget_badge = has_widget ? " 🎨 widget" : ""

        puts "  #{mode_emoji} #{cyan}#{tool_name}#{reset} #{dim}#{mode_color}#{mode_label}#{reset}#{widget_badge}"

        wrapped = wrap_text.call(description, text_width)
        puts "  ┌#{"─" * (text_width + 2)}┐"
        wrapped.each { |line| puts "  │ #{line.ljust(text_width)} │" }
        puts "  └#{"─" * (text_width + 2)}┘"
        puts
      end
    end
  end
end
