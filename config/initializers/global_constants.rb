########################################
# Global constants (app-wide settings) #
########################################

APP_NAME              = "phish.in"              # App name appears in page title, correspondence, etc
TMP_PATH              = "#{Rails.root}/tmp/"    # Location for writing temporary files
ALBUM_CACHE_MAX_SIZE  = 20.gigabytes            # Maximum size of album attachment cache

if Rails.env == 'development' || Rails.env == 'test'
  APP_BASE_URL              = "http://localhost:3000"
  APP_CONTENT_PATH          = "/htdocs/app_content/phishin"
else
  APP_BASE_URL              = "http://phish.in"
  APP_CONTENT_PATH          = "/var/www/app_content/phishin"
end