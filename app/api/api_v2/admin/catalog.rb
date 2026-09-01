class ApiV2::Admin::Catalog < ApiV2::Admin::Base
  SEARCH_LIMIT = 20
  TOUR_LIMIT = 50

  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    resource :songs do
      desc "Search songs", hidden: true
      params do
        optional :q, type: String
      end
      # Substring match rather than the site's full-text kinda_matching: that
      # search works on whole words, so a half-typed title ("harpu") finds
      # nothing while the admin is still typing it.
      get do
        songs =
          if params[:q].present?
            Song.where("title ILIKE :term", term: "%#{params[:q]}%")
                .order(:title).limit(SEARCH_LIMIT)
          else
            Song.order(:title).limit(SEARCH_LIMIT)
          end
        { songs: songs.map { |song| song_payload(song) } }
      end

      desc "Create a song", hidden: true
      params do
        requires :title, type: String
        optional :original, type: Boolean, default: false
        optional :artist, type: String
      end
      post do
        title = params[:title].strip
        # Songs are a public catalog, so a near-duplicate is reported rather than
        # created. Titles are unique case-sensitively in the database, so the
        # pre-check is case-insensitive to catch "new jam" against "New Jam".
        if Song.where("LOWER(title) = ?", title.downcase).exists?
          error!({ message: "A song titled \"#{title}\" already exists" }, 409)
        end
        artist = params[:artist].to_s.strip
        if !params[:original] && artist.empty?
          error!({ message: "A cover needs its original artist" }, 422)
        end
        song = Song.create!(title:, original: params[:original], artist: params[:original] ? nil : artist)
        status 201
        song_payload(song)
      end
    end

    resource :venues do
      desc "Search venues", hidden: true
      params do
        optional :all, type: Boolean, default: false, desc: "Return every venue"
        optional :q, type: String
      end
      get do
        venues = Venue.order(:name)
        venues = venues.limit(SEARCH_LIMIT) unless params[:all]
        if params[:q].present?
          venues = venues.where("venues.name ILIKE :term", term: "%#{params[:q]}%")
        end
        { venues: venues.map { |venue| venue_payload(venue) } }
      end

      desc "Create a venue", hidden: true
      params do
        requires :name, type: String
        requires :city, type: String
        optional :state, type: String
        requires :country, type: String
        optional :latitude, type: Float, values: -90.0..90.0
        optional :longitude, type: Float, values: -180.0..180.0
      end
      post do
        name = params[:name].strip
        city = params[:city].strip
        if Venue.where("LOWER(name) = ? AND LOWER(city) = ?", name.downcase, city.downcase).exists?
          error!({ message: "A venue named \"#{name}\" already exists in #{city}" }, 409)
        end
        # venues.state is NOT NULL; venues outside the USA store a blank string.
        venue = Venue.create!(
          name:,
          city:,
          state: params[:state].to_s.strip,
          country: params[:country].strip,
          latitude: params[:latitude],
          longitude: params[:longitude]
        )
        status 201
        venue_payload(venue)
      end
    end

    resource :tours do
      desc "Search tours", hidden: true
      params do
        optional :q, type: String
      end
      get do
        tours = Tour.order(starts_on: :desc).limit(TOUR_LIMIT)
        tours = tours.where("tours.name ILIKE :term", term: "%#{params[:q]}%") if params[:q].present?
        { tours: tours.map { |tour| tour_payload(tour) } }
      end

      desc "Create a tour", hidden: true
      params do
        requires :name, type: String
        requires :starts_on, type: Date
        requires :ends_on, type: Date
      end
      post do
        name = params[:name].strip
        starts_on = params[:starts_on]
        ends_on = params[:ends_on]
        error!({ message: "ends_on must be on or after starts_on" }, 422) if ends_on < starts_on

        # starts_on and ends_on each carry their own uniqueness constraint, so an
        # overlapping tour collides on a date even when the name is new.
        conflict = tour_conflict(name, starts_on, ends_on)
        error!({ message: conflict }, 409) if conflict

        tour = Tour.create!(name:, starts_on:, ends_on:)
        status 201
        tour_payload(tour)
      end
    end
  end

  helpers do
    def song_payload(song)
      { id: song.id, title: song.title, slug: song.slug }
    end

    def venue_payload(venue)
      {
        id: venue.id,
        name: venue.name,
        city: venue.city,
        state: venue.state,
        country: venue.country,
        slug: venue.slug
      }
    end

    def tour_payload(tour)
      {
        id: tour.id,
        name: tour.name,
        starts_on: tour.starts_on.iso8601,
        ends_on: tour.ends_on.iso8601,
        slug: tour.slug
      }
    end

    def tour_conflict(name, starts_on, ends_on)
      if Tour.where("LOWER(name) = ?", name.downcase).exists?
        "A tour named \"#{name}\" already exists"
      elsif Tour.exists?(starts_on:)
        "A tour already starts on #{starts_on.iso8601}"
      elsif Tour.exists?(ends_on:)
        "A tour already ends on #{ends_on.iso8601}"
      end
    end
  end
end
