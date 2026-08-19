RSpec.configure do |config|
  # Rake-task services report progress on stdout. That noise buries the spec
  # results, so swallow it by default. Tag a spec with `:show_output` to see it,
  # and use `expect { ... }.to output(...).to_stdout` to assert on it.
  config.around do |example|
    next example.run if example.metadata[:show_output]

    original = $stdout
    $stdout = StringIO.new
    begin
      example.run
    ensure
      $stdout = original
    end
  end

  # ProgressBar captures the STDOUT constant when it is built, so reassigning
  # $stdout above does not silence it. Point it at the current $stdout instead.
  config.before do
    next if RSpec.current_example&.metadata&.dig(:show_output)

    allow(ProgressBar).to receive(:create).and_wrap_original do |original, **opts|
      original.call(**opts, output: $stdout)
    end
  end
end
