class CoverArtGenerator < BaseService
  param :show
  option :force, default: -> { false }

  def call
    generate_prompt_and_image_assets
  end

  private

  def generate_prompt_and_image_assets
    if force || (show.cover_art_prompt.blank? && show.cover_art_parent_show_id.blank?)
      CoverArtPromptService.new(show).call
      if show.cover_art_parent_show_id.present?
        puts "PROMPT (DEFER): #{show.cover_art_parent_show_id}"
      else
        puts "PROMPT (NEW): #{show.cover_art_prompt}"
      end
    end

    if force || !show.cover_art.attached?
      CoverArtImageService.new(show).call
      # sleep 5 # for Dall-E API rate limiting
      puts show.cover_art_urls[:large]
    end

    if force || !show.album_cover.attached?
      AlbumCoverService.new(show).call
      puts show.album_cover_url

      # Apply cover art to mp3 files
      show.tracks.each do |track|
        track.apply_id3_tags
      end
    end
  end
end
