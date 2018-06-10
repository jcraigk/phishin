# frozen_string_literal: true
require_relative '../../config/environment'
require_relative '../filename_matcher'
require_relative 'show_importer'
require_relative 'show_info'
require_relative 'track_proxy'
require_relative 'cli'

if $PROGRAM_NAME == __FILE__
  exit puts 'Need date' if ARGV.empty?
  ShowImporter::Cli.new
end
