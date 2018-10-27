# frozen_string_literal: true
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
require 'bundler/setup'

require 'dotenv/load' unless ENV['IN_DOCKER']
