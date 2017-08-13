require_relative '../../config/environment'
require_relative '../filename_matcher'
require_relative 'show_importer'
require_relative 'show_info'
require_relative 'track_proxy'
require_relative 'cli'

if __FILE__ == $PROGRAM_NAME
  if ARGV.empty?
    puts 'Need date'
    exit
  end

  ShowImporter::Cli.new
end
