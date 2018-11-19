# frozen_string_literal: true
module TimeHelpers
  RSpec.configure do |config|
    config.around(:each, :timecop) do |example|
      destination_time =
        begin
          Time.at(example.metadata[:freeze_time])
        rescue TypeError
          Time.current
        end
      Timecop.travel(destination_time) { example.run }
    end
  end
end
