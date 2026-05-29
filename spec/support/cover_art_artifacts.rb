# Writes images produced by the cover art pipeline to tmp/spec_artifacts/cover_art/
# so they can be inspected after a spec run. See spec/services/cover_art_pipeline_spec.rb.
module CoverArtArtifacts
  DIR = Rails.root.join("tmp/spec_artifacts/cover_art")

  module_function

  # Clear and recreate the artifact directory. Called once when the pipeline spec runs.
  def reset!
    FileUtils.rm_rf(DIR)
    FileUtils.mkdir_p(DIR)
  end

  # Download an attachment or processed variant and write it to <name>.jpg.
  # Returns the path so the caller can read it back for assertions.
  def dump(name, downloadable)
    path = DIR.join("#{name}.jpg")
    File.binwrite(path, downloadable.download)
    path
  end
end
