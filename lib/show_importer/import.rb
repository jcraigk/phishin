require_relative '../../config/environment'
require_relative '../filename_matcher'
require_relative 'show_importer'
require_relative 'show_info'
require_relative 'track_proxy'
require_relative 'cli'

if __FILE__ == $0
  if ARGV.length < 1
    puts 'Need date'
    exit
  end
  
  ShowImporter::Cli.new
end
