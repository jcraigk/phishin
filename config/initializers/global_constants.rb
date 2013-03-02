########################################
# Global constants (app-wide settings) #
########################################

APP_NAME              = "phish.in"
TMP_PATH              = "#{Rails.root}/tmp/"   # Location for writing temporary files
ALBUM_CACHE_MAX_SIZE  = 500.megabytes          # Maximum size of album attachment cache

PAPERCLIP_SECRET = "CROUOPQNDKUCBVYTQYQLUSKCOMJAQFEWXMEX"

if Rails.env == 'development' || Rails.env == 'test'
  APP_BASE_URL              = "http://localhost:3000"
  PAPERCLIP_BASE_DIR        = "/htdocs/app_content/phishin"
else
  APP_BASE_URL              = "http://phish.in"
  PAPERCLIP_BASE_DIR        = "/var/www/app_content/phishin"
end
