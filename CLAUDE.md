# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Phish.in is an open source archive of live Phish audience recordings built with Ruby on Rails and React. The application provides a web interface and JSON API for browsing and playing audio content from Phish concerts.

## Architecture

**Backend (Rails API)**
- Rails 8 application with PostgreSQL database
- Grape API framework for v2 JSON API endpoints (`app/api/api_v2/`)
- Traditional Rails controllers for v1 API (`app/controllers/api/`)
- ActiveStorage for file attachments (audio, waveforms, cover art)
- Sidekiq for background job processing
- Sorcery gem for authentication

**Frontend (React SSR)**
- React 18 with server-side rendering via react-on-rails
- Shakapacker (webpack) for asset compilation
- Bulma CSS framework for styling
- Components organized in `app/javascript/components/`

**Key Models & Relationships**
- `Show` - Central model representing live concerts with date, venue, tour
- `Track` - Individual songs from shows with audio files and metadata
- `Song` - Song catalog (original compositions vs covers)
- `Venue`/`Tour` - Location and tour information
- `Tag` - Metadata system for shows/tracks (jams, debuts, bustouts, etc.)
- `Playlist` - User-created playlists of tracks
- `User` - Authentication and user data

## Development Commands

**Setup (Docker)**
```bash
make services     # Start PostgreSQL and Redis containers
make dev          # Native development (recommended)
make up           # Full Docker development
```

**Setup (Native)**
```bash
bundle install    # Install Ruby dependencies
yarn install      # Install Node dependencies
foreman start -f Procfile.dev  # Start all services
```

**Testing**
```bash
make spec                    # Run tests in Docker
bundle exec rspec           # Run tests natively
bundle exec rspec spec/path # Run specific test file
```

**Linting & Code Quality**
```bash
bundle exec rubocop         # Ruby linting
bundle exec rubocop -a      # Auto-fix Ruby issues
```

**Database**
```bash
bundle exec rails db:migrate # Run migrations
bundle exec rails db:setup RAILS_ENV=test # Setup test database
```

**Content Management**
```bash
bundle exec rails shows:import  # Import show content (requires PNET_API_KEY)
```

## Development Patterns

**API Structure**
- V1 API: Traditional Rails controllers in `app/controllers/api/`
- V2 API: Grape-based in `app/api/api_v2/` with Swagger documentation
- API authentication via JWT tokens and API keys

**Service Objects**
- Business logic extracted to service classes in `app/services/`
- Services follow naming convention: `*Service` (e.g., `SearchService`, `GapService`)
- Use dry-initializer gem for service initialization

**Background Jobs**
- Sidekiq jobs in `app/jobs/` for async processing
- Album ZIP creation, waveform generation, content import

**Frontend Organization**
- React components in `app/javascript/components/`
- Pages and layout components separated
- SCSS styles in `app/javascript/stylesheets/`

## Testing Strategy

- RSpec for Ruby tests with FactoryBot factories
- Feature tests use Capybara with Selenium WebDriver
- Test database reset between runs
- Coverage reporting with SimpleCov

## Key Configuration

- **Environment**: Uses dotenv-rails for local `.env` configuration
- **Authentication**: Sorcery with OAuth provider support
- **File Storage**: ActiveStorage with S3 backend in production
- **Background Processing**: Sidekiq with Redis
- **Search**: pg_search for PostgreSQL full-text search
- **Caching**: Action caching and Dalli for memcached

## Import & Content Management

The application imports Phish show data from Phish.net API. Audio files are organized by date folders in `./content/import/` and processed through the import system that:
1. Matches filenames to setlist data
2. Generates waveforms and metadata
3. Creates database records
4. Processes audio files for web delivery