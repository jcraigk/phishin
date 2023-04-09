# frozen_string_literal: true
require_relative 'config/application'
Rails.application.load_tasks


desc "Print out routes"
task :routes => :environment do
  Phishin::V2::Api::Root.routes.each do |route|
    info = route.instance_variable_get :@options
    description = "%-40s..." % info[:description][0..39]
    method = "%-7s" % info[:method]
    puts "#{description}  #{method}#{info[:path]}"
  end
end
