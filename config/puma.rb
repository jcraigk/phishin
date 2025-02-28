require "puma"

threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count
port 3000
environment ENV.fetch("RAILS_ENV", "development")
plugin :tmp_restart
