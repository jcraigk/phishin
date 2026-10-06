class CoverArtRunLinker < ApplicationService
  param :show

  def call
    kickoff = show.cover_art_run_kickoff
    kickoff == show ? unlink : link_to(kickoff)
  end

  private

  def unlink
    show.update!(cover_art_parent_show_id: nil) if show.cover_art_parent_show_id
  end

  def link_to(parent)
    show.update!(cover_art_parent_show_id: parent.id, cover_art_prompt: parent.cover_art_prompt)
    inherit_cover_art(parent) if parent.cover_art.attached?
  end

  def inherit_cover_art(parent)
    return if show.cover_art.attached? && show.cover_art.blob_id == parent.cover_art.blob_id
    show.cover_art.attach(parent.cover_art.blob)
    show.update!(cover_art_model: parent.cover_art_model)
    AlbumCoverService.call(show)
    show.tracks.order(:position).each(&:apply_id3_tags)
  end
end
