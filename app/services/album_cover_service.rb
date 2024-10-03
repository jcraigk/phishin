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
    download_cover_art
    composite_text_on_cover_art
    attach_album_cover
  end

  private

  def download_cover_art
    url = Rails.application.routes.url_helpers.rails_blob_url(show.cover_art)
    image_response = Typhoeus.get(url, followlocation: true)
    @art_path = Rails.root.join("tmp", "#{SecureRandom.hex}.jpg")
    File.open(@art_path, "wb") do |file|
      file.binmode
      file.write(image_response.body)
    end
    puts "Downloaded file size: #{File.size(@art_path)} bytes"

    unless File.exist?(@art_path)
      raise "Cover art file not found after download."
    end
  end

  def composite_text_on_cover_art
    @art = MiniMagick::Image.open(@art_path)
    text_color = "#222222"
    bg_color = "#f2f3f5"
    font1 = Rails.root.join("lib/fonts/Molle-Italic.ttf")
    font2 = Rails.root.join("lib/fonts/OpenSans_Condensed-Light.ttf")

    # Solid color bg at bottom
    bg_block_path = Rails.root.join("tmp", "#{SecureRandom.hex}.png").to_s
    MiniMagick::Tool::Magick.new do |cmd|
      cmd.size "#{@art.width}x#{(@art.height * 0.2).to_i}"
      cmd.canvas bg_color
      cmd << bg_block_path
    end

    # Bg dropshadow
    gradient_path = Rails.root.join("tmp", "#{SecureRandom.hex}.png").to_s
    MiniMagick::Tool::Magick.new do |cmd|
      cmd.size "#{@art.width}x#{(@art.height * 0.015).to_i}"
      cmd.gradient "none-rgba(128,128,128,0.3)"
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
      c.pointsize 75
      c.antialias
      c.fill text_color
      c.draw "text 20,0 '#{text}'"
    end

    # Date
    text = show.date.to_s.gsub("-", ".")
    @art.combine_options do |c|
      c.gravity "SouthEast"
      c.font font2
      c.pointsize 35
      c.antialias
      c.fill text_color
      c.draw "text 20,44 '#{text}'"
    end

    # Venue
    text = show.venue_name.truncate(35, omission: "...").gsub("'", "\\\\'")
    @art.combine_options do |c|
      c.gravity "SouthEast"
      c.font font2
      c.pointsize 21
      c.antialias
      c.fill text_color
      c.draw "text 20,19 '#{text}'"
    end

    File.delete(bg_block_path) if File.exist?(bg_block_path)
    File.delete(gradient_path) if File.exist?(gradient_path)
  end

  def attach_album_cover
    album_cover_path = Rails.root.join("tmp", "#{SecureRandom.hex}.jpg")
    @art.write(album_cover_path.to_s) { |img| img.quality 90 }
    show.album_cover.attach \
      io: File.open(album_cover_path),
      filename: "album_cover_#{show.id}.jpg",
      content_type: "image/jpeg"
    File.delete(@art_path) if File.exist?(@art_path)
    File.delete(album_cover_path) if File.exist?(album_cover_path)
  end
end
