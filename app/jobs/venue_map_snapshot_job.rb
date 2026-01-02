require "typhoeus"
require "mini_magick"

class VenueMapSnapshotJob
  include Sidekiq::Job

  ZOOM = 4
  STYLE = "mapbox/streets-v12"
  PIN_COLOR = "03BBF2"
  REQUEST_SIZE = 256
  EXTRA_HEIGHT = 40
  OUTPUT_SIZE = 512

  def perform(venue_id)
    @venue = Venue.find_by(id: venue_id)
    return unless @venue

    generate_and_attach_map
  end

  private

  def generate_and_attach_map
    return unless map_center

    response = Typhoeus.get(mapbox_static_url)

    unless response.success?
      Rails.logger.error("VenueMapSnapshotJob: Failed to fetch map for venue #{@venue.id}: #{response.code}")
      return
    end

    Tempfile.create([ "venue_map_#{@venue.id}_raw", ".png" ]) do |raw_file|
      raw_file.binmode
      raw_file.write(response.body)
      raw_file.rewind

      Tempfile.create([ "venue_map_#{@venue.id}", ".png" ]) do |output_file|
        crop_image(raw_file.path, output_file.path)

        @venue.map_snapshot.attach(
          io: File.open(output_file.path),
          filename: "venue_#{@venue.id}_map.png",
          content_type: "image/png"
        )
      end
    end
  end

  def crop_image(input_path, output_path)
    image = MiniMagick::Image.open(input_path)
    image.crop("#{OUTPUT_SIZE}x#{OUTPUT_SIZE}+0+0")
    image.write(output_path)
  end

  def mapbox_static_url
    request_height = REQUEST_SIZE + EXTRA_HEIGHT
    size = "#{REQUEST_SIZE}x#{request_height}@2x"
    center = map_center
    marker = "pin-s+#{PIN_COLOR}(#{center})"

    "https://api.mapbox.com/styles/v1/#{STYLE}/static/" \
      "#{marker}/#{center},#{ZOOM}/#{size}" \
      "?access_token=#{ENV.fetch('MAPBOX_STATIC_TOKEN', ENV.fetch('MAPBOX_TOKEN'))}"
  end

  def map_center
    @map_center ||=
      if @venue.has_coordinates?
        "#{@venue.longitude},#{@venue.latitude}"
      else
        geocode_location
      end
  end

  def geocode_location
    url = "https://api.mapbox.com/geocoding/v5/mapbox.places/#{CGI.escape(@venue.location)}.json" \
          "?access_token=#{ENV.fetch('MAPBOX_TOKEN')}&limit=1"
    response = Typhoeus.get(url)
    return nil unless response.success?

    data = JSON.parse(response.body)
    coords = data.dig("features", 0, "center")
    return nil unless coords

    "#{coords[0]},#{coords[1]}"
  end
end
