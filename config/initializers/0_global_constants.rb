########################################
# Global constants (app-wide settings) #
########################################

# QUEUE=* bundle exec rake resque:work RAILS_ENV=production BACKGROUND=yes

HTAUTH_USERNAME             = 'treyiswilson'
HTAUTH_PASSWORD             = 'treyiswilson'

APP_NAME                    = "phish.in'"                             # App name appears in page title, correspondence, etc
APP_EMAIL                   = "phish.in.music@gmail.com"              # Main contact email
DEVISE_EMAIL_FROM           = "phish.in' <noreply@phish.in>"          # From address for Devise emails

ALBUM_CACHE_MAX_SIZE        = 50.gigabytes                            # Maximum size of album attachment cache
ALBUM_TIMEOUT               = 10.seconds                              # Time to wait for album creation before telling user

CACHE_TTL                   = 10.minutes

FIRST_CHAR_LIST             = ('A'..'Z').to_a + ['#']                 # Characters to include in A..B..C.. links
MAX_PLAYLISTS_PER_USER      = 20                                      # Max number of playlists a user may create

if Rails.env == 'development' || Rails.env == 'test'
  APP_BASE_URL              = "http://localhost:3000"
  APP_CONTENT_PATH          = "/htdocs/app_content/phishin/"
  TMP_PATH                  = "/htdocs/app_content/phishin/tmp/"
else
  APP_BASE_URL              = "http://phish.in"
  APP_CONTENT_PATH          = "/var/www/app_content/phishin/"
  TMP_PATH                  = "/var/www/app_content/phishin/tmp/"
end

ERAS = {
  '1.0' => ['1983-1987', '1988', '1989', '1990', '1991', '1992', '1993', '1994', '1995', '1996', '1997', '1998', '1999', '2000'],
  '2.0' => ['2002', '2003', '2004'],
  '3.0' => ['2009', '2010', '2011', '2012', '2013', '2014', '2015']
}
