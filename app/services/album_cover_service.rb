require "mini_magick"

class AlbumCoverService < BaseService
  extend Dry::Initializer

  param :show

  def call
    return unless show.cover_art.attached?
    create_album_cover
  end

  private

  def create_album_cover
    composite_text_on_cover_art
    attach_album_cover
  end

  private

  def composite_text_on_cover_art
    @art = MiniMagick::Image.open(show.cover_art_path)
    text_color = "#222222"
    bg_color = "#e5e5e5"
    font1 = Rails.root.join("lib/fonts/Molle-Italic.ttf")
    font2 = Rails.root.join("lib/fonts/OpenSans_Condensed-Light.ttf")

    # Solid color bg at bottom
    bg_block_path = Rails.root.join("tmp", "#{SecureRandom.hex}.png").to_s
    MiniMagick::Tool::Convert.new do |cmd|
      cmd.size "#{@art.width}x#{(@art.height * 0.2).to_i}"
      cmd.canvas bg_color
      cmd << bg_block_path
    end

    # Bg dropshadow
    gradient_path = Rails.root.join("tmp", "#{SecureRandom.hex}.png").to_s
    MiniMagick::Tool::Convert.new do |cmd|
      cmd.size "#{@art.width}x#{(@art.height * 0.015).to_i}"
      cmd.gradient "none-rgba(34,34,34,0.55)"
      cmd << gradient_path
    end

    # Composite the bg and gradient
    bg_block = MiniMagick::Image.open(bg_block_path)
    gradient = MiniMagick::Image.open(gradient_path)
    @art = @art.composite(bg_block) do |c|
      c.compose "over"
      c.gravity "south"
    end
    @art = @art.composite(gradient) do |c|
      c.compose "over"
      c.gravity "south"
      c.geometry "+0+#{(@art.height * 0.2).to_i}"
    end

    # Phish
    text = "Phish"
    @art.combine_options do |c|
      c.gravity "SouthWest"
      c.font font1
      c.pointsize 140
      c.antialias
      c.fill text_color
      c.draw "text 40,2 '#{text}'"
    end

    # Date
    text = show.date.strftime("%b %-d, %Y")
    @art.combine_options do |c|
      c.gravity "SouthEast"
      c.font font2
      c.pointsize 60
      c.antialias
      c.fill text_color
      c.draw "text 40,92 '#{text}'"
    end

    # Venue
    text = smart_truncate(show.venue_name).gsub("'", "\\\\'")
    @art.combine_options do |c|
      c.gravity "SouthEast"
      c.font font2
      c.pointsize 40
      c.antialias
      c.fill text_color
      c.draw "text 40,42 '#{text}'"
    end

    File.delete(bg_block_path) if File.exist?(bg_block_path)
    File.delete(gradient_path) if File.exist?(gradient_path)
  end

  # Remove any non-alphabetic characters before the omission
  def smart_truncate(text, length: 35, omission: "...")
    truncated = text.truncate(length, omission:)
    truncated.sub(/[^a-zA-Z]+#{Regexp.escape(omission)}\z/, omission)
  end

  def attach_album_cover
    album_cover_path = Rails.root.join("tmp", "#{SecureRandom.hex}.jpg")
    @art.write(album_cover_path.to_s) { |img| img.quality 90 }
    show.album_cover.attach \
      io: File.open(album_cover_path),
      filename: "album_cover_#{show.id}.jpg",
      content_type: "image/jpeg"
    File.delete(album_cover_path) if File.exist?(album_cover_path)
  end
end
