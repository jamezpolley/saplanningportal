require "capybara"
require "selenium-webdriver"

require "json"
require "scraperwiki"
require "logger"

Capybara.register_driver :selenium_chrome_headless_morph do |app|
  Capybara::Selenium::Driver.load_selenium
  browser_options = ::Selenium::WebDriver::Chrome::Options.new.tap do |opts|
    opts.args << '--headless'
    opts.args << '--disable-gpu' if Gem.win_platform?
    # Workaround https://bugs.chromium.org/p/chromedriver/issues/detail?id=2650&q=load&sort=-id&colspec=ID%20Status%20Pri%20Owner%20Summary
    opts.args << '--disable-site-isolation-trials'
    opts.args << '--no-sandbox'
  end
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
end

# Open a Capybara session with the Selenium web driver for Chromium headless
capybara = Capybara::Session.new(:selenium_chrome_headless_morph)

# This endpoint is not "protected" by Kasada
url = "https://plan.sa.gov.au/have_your_say/notified_developments/current_notified_developments/assets/getpublicnoticessummary"
applications = JSON.parse(capybara.visit(url).body)
applications.each do |application|
  record = {
    "council_reference" => application["applicationID"].to_s,
    # If there are multiple addresses they are all included in this field separated by ","
    # Only use the first address
    "address" => application["propertyAddress"].split(",").first,
    "description" => application["developmentDescription"],
    # Not clear whether this page will stay around after the notification period is over
    "info_url" => "https://plan.sa.gov.au/have_your_say/notified_developments/current_notified_developments/submission?aid=#{application['publicNotificationID']}",
    "date_scraped" => Date.today.to_s,
    "on_notice_to" => Date.strptime(application["closingDate"], "%m/%d/%Y").to_s
  }

  # Instead of sending all comments to PlanSA we want to send comments to the individual councils
  # Luckily that information (the email address) is available by call the "detail" endpoint
  #page = agent.post("https://plan.sa.gov.au/have_your_say/notified_developments/current_notified_developments/assets/getpublicnoticedetail", aid: application["applicationID"])
  # detail = JSON.parse(page.body)
  # record["comment_email"] = detail["email"]
  # record["comment_authority"] = detail["organisation"]

  puts "Saving record #{record['council_reference']}, #{record['address']}"
  ScraperWiki.save_sqlite(['council_reference'], record)
end