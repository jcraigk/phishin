class Admin::ShiftBoundaryJob
  include Sidekiq::Job
  include LameEncoding

  MIN_PART_S = 1.0
  PREVIEW_WINDOW_S = 5.0

  class NoNextTrackError < StandardError; end
  class MissingAudioError < StandardError; end
  class DeltaOutOfRangeError < StandardError; end

  def perform(track_id, admin_job_id, delta_s, apply)
    @first = Track.find(track_id)
    @delta_s = delta_s.to_f
    @apply = apply
    admin_job = AdminJob.find(admin_job_id)

    @admin_job = admin_job

    admin_job.run! do
      find_second!
      ensure_audio!
      ensure_delta_in_stored_range!
      join
      ensure_delta_in_range!
      render_sides
      store_renders(admin_job)
      apply! if apply?
      admin_job.payload.merge!(payload)
      admin_job.save!
    end
  end

  private

  attr_reader :first, :second, :delta_s

  def apply? = @apply

  def show = first.show

  def label = "#{show.date} #{first.title}"

  def find_second!
    @second = show.tracks.find_by(position: first.position + 1)
    return if @second
    raise NoNextTrackError,
          "#{show.date} #{first.title}: no track below position #{first.position}"
  end

  def ensure_audio!
    missing = [ first, second ].reject { it.mp3_audio.attached? }
    return if missing.empty?
    raise MissingAudioError,
          "no audio attached: #{missing.map { "#{show.date} #{it.title}" }.join(', ')}"
  end

  def join
    @concat = TrackConcatService.call(tracks: [ first, second ])
    @joined_path = @concat[:output_path]
  end

  def first_duration_s = @concat[:source_durations].first

  def total_duration_s = @concat[:duration_s]

  def cut_s
    @cut_s ||= (first_duration_s + delta_s).round(2)
  end

  def allowed_range
    [ (MIN_PART_S - first_duration_s).round(1),
      (total_duration_s - MIN_PART_S - first_duration_s).round(1) ]
  end

  def ensure_delta_in_stored_range!
    low = (MIN_PART_S - first.duration.to_i / 1000.0).round(1)
    high = (second.duration.to_i / 1000.0 - MIN_PART_S).round(1)
    return if delta_s >= low && delta_s <= high
    raise DeltaOutOfRangeError, out_of_range_message(low, high)
  end

  def ensure_delta_in_range!
    return if cut_s >= MIN_PART_S && cut_s <= total_duration_s - MIN_PART_S
    raise DeltaOutOfRangeError, out_of_range_message(*allowed_range)
  end

  def out_of_range_message(low, high)
    "delta of #{delta_s.round(1)}s moves the boundary outside the audio; " \
      "allowed range is #{low}s to #{high}s"
  end

  def output_dir = Rails.root.join("tmp/track_boundaries")

  def side_paths
    @side_paths ||= [ 1, 2 ].map do |n|
      output_dir.join("#{show.date}_#{first.slug}_boundary#{n}.mp3")
    end
  end

  def bitrate
    @bitrate ||= begin
      raw = Admin::AudioProbe.read(@joined_path, "format=bit_rate").to_s
      /\A\d+\z/.match?(raw) ? "#{(raw.to_i / 1000.0).round}k" : "192k"
    end
  end

  def render_sides
    FileUtils.mkdir_p(output_dir)
    if apply?
      render_side_via_lame(TrackSplitService.filters(start_s: 0.0, end_s: cut_s), side_paths[0])
      render_side_via_lame(TrackSplitService.filters(start_s: cut_s), side_paths[1])
    else
      render(TrackSplitService.filters(start_s: [ cut_s - PREVIEW_WINDOW_S, 0.0 ].max, end_s: cut_s), side_paths[0])
      render(TrackSplitService.filters(start_s: cut_s, end_s: [ cut_s + PREVIEW_WINDOW_S, total_duration_s ].min), side_paths[1])
    end
  end

  def render_side_via_lame(filters, out_path)
    render_via_lame(out_path, [ "-i", @joined_path, "-af", filters.join(",") ])
  end

  def render(filters, out_path)
    _out, err, status = Open3.capture3(
      "ffmpeg", "-y", "-v", "error", "-i", @joined_path,
      "-af", filters.join(","), "-map_metadata", "0", "-id3v2_version", "3",
      "-b:a", bitrate, out_path.to_s
    )
    raise TrackConcatService::Error, "ffmpeg failed for #{show.date}: #{err}" unless status.success?
  end

  def store_renders(admin_job)
    admin_job.payload["audio_paths"] = [
      AdminJobAudio.store(admin_job, side_paths[0].to_s, index: 0),
      AdminJobAudio.store(admin_job, side_paths[1].to_s, index: 1)
    ]
  end

  def apply!
    @backup_paths = [ back_up(first), back_up(second) ]
    attach(first, side_paths[0])
    attach(second, side_paths[1])
    shift_timestamps
  end

  def shift_timestamps
    @shifts = {
      first => TimestampShifter.call(
        track: first.reload, delta_s: 0.0, new_duration_s: new_durations[0],
        reason: "shift_boundary"
      ),
      second => TimestampShifter.call(
        track: second.reload, delta_s: -delta_s, new_duration_s: new_durations[1],
        reason: "shift_boundary"
      )
    }
  end

  def new_durations
    @new_durations ||= [ cut_s, total_duration_s - cut_s ].map { it.round(1) }
  end

  def back_up(record)
    AudioBackup.store(record, operation: "shift_boundary")
  end

  def attach(record, path)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(path),
      filename: record.friendly_filename,
      content_type: "audio/mpeg"
    )
    TrackAudioReplacer.call(track: record.reload, blob:)
    blob.purge
  end

  def payload
    {
      "track_id" => first.id,
      "second_track_id" => second.id,
      "delta_s" => delta_s.round(2),
      "cut_s" => cut_s,
      "reencoded" => @concat[:reencoded],
      "total_duration_s" => total_duration_s,
      "source_durations" => @concat[:source_durations],
      "new_durations" => new_durations,
      "backup_paths" => @backup_paths
    }.compact
  end
end
