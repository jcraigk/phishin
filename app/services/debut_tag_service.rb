class DebutTagService < ApplicationService
  param :show

  def call
    show.tracks.each do |track|
      track.songs.each do |song|
        next unless song.tracks_count == 1
        apply_debut_tag(track)
      end
    end
  end

  private

  def apply_debut_tag(track)
    ttag = track.track_tags.find { it.tag == debut_tag } || track.track_tags.build(tag: debut_tag)
    ttag.save!
  end

  def debut_tag
    @debut_tag ||= Tag.find_by!(name: "Debut")
  end
end
