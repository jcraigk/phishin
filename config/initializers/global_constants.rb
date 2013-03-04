########################################
# Global constants (app-wide settings) #
########################################

APP_NAME              = "phish.in"                  # App name appears in page title, correspondence, etc
APP_EMAIL             = "phish.in.music@gmail.com"  # Main contact email
ALBUM_CACHE_MAX_SIZE  = 500.megabytes                # Maximum size of album attachment cache
ALBUM_TIMEOUT         = 10.seconds                  # Time to wait for album creation before telling user

if Rails.env == 'development' || Rails.env == 'test'
  APP_BASE_URL              = "http://localhost:3000"
  APP_CONTENT_PATH          = "/htdocs/app_content/phishin/"
  TMP_PATH                  = "/htdocs/app_content/phishin/tmp/"
else
  APP_BASE_URL              = "http://phish.in"
  APP_CONTENT_PATH          = "/var/www/app_content/phishin"
  TMP_PATH                  = "/htdocs/app_content/phishin/tmp/"
end