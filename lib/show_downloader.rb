require_relative '../config/environment'
require 'readline'

module StreamPhish
  class Downloader
    SHOW_LINKS_CSS = '#main_files_container ol li > a'
    SCREENSHOTS_DIR = "#{Rails.root}/public/screenshots"
    # SCREENSHOTS_DIR = "/var/streamphish/public/screenshots"

    attr_reader :driver
    attr_accessor :date

    def initialize(link_from_sprdsht, date)
      @driver = Selenium::WebDriver.for :firefox
      @date = Date.strptime date, '%m/%d/%Y'
      @driver.navigate.to link_from_sprdsht
    end

    def download_show_link(link, part=0)
      @driver.navigate.to link

      @_captcha = @driver.find_element(:id => 'adcopy_response') rescue \
                    @driver.find_element(:id => 'recaptcha_response_field') rescue \
                      nil
      if @_captcha
        @driver.execute_script "$('button.btn.secondary.cancelBtn').click()"
        puts screenshot
        if @_captcha.tag_name == 'select'
          @_captcha = nil
          download_link(link) and return
        else
          handle_text_captcha
        end
      end

      wait.until { show_link }

      puts "Attempting to download..."
      download_url @_show_link['href'], part
    end

    def show_link
      @_show_link = @driver.find_element(:css => '.download_link a') rescue nil
    end

    def show_links
      wait.until { @driver.find_element(:css => SHOW_LINKS_CSS) }

      @driver.find_elements(:css => SHOW_LINKS_CSS).map{|e| e['href']}
    end

    def download_files
      sl = show_links
      sl.each_with_index do |show_link, i|
        download_show_link(show_link, sl.length > 1 ? i+1 : 0)
      end
    end

    private

    def wait(timeout = 10.seconds)
      Selenium::WebDriver::Wait.new(:timeout => timeout, :interval => 0.5)
    end

    def random_filename
      (0...32).map{65.+(rand(25)).chr}.join + ".png"
    end

    def screenshot
      filename = random_filename
      @driver.save_screenshot "#{SCREENSHOTS_DIR}/#{filename}"
      "#{Rails.application.routes.url_helpers.root_url}screenshots/#{filename}"
    end

    def download_url(url, part=0)
      fname  = date.strftime("%-m-%-d-%Y") + (part != 0 ? ".#{part}" : '') + ".rar"
      f      = open("#{fname}", "wb")
      uri    = URI(url)
      http   = Net::HTTP.new uri.host, uri.port

      begin
        http.request_get(uri.path) do |resp|
          unless resp.is_a?(Net::HTTPOK)
            puts resp.class
            break
          end
          puts "downloading to #{f.path}!"
          resp.read_body { |segment| f.write segment }
        end
      ensure
        f.close
      end
    end

    def handle_text_captcha
      while answer = Readline.readline('> ', false)
        @_captcha.send_keys answer
        @_captcha.submit
        @_captcha = nil
        break
      end
    end

    def handle_select_captcha
      puts 'handle select captcha'
    end

    def handle_captcha
      if @_captcha.tag_name == 'input'
        handle_text_captcha
      else
        handle_select_captcha
      end
      @_captcha = nil
    end

  end
end

if __FILE__ == $0
  if ARGV.length < 2
    puts "Need 2 args"
  else
    puts "Making downloader..."
    d = StreamPhish::Downloader.new ARGV[0], ARGV[1]
    puts "Downloading files..."
    d.download_files
  end
end