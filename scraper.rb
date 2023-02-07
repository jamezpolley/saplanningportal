require "mechanize"
require "json"
require "scraperwiki"

agent = Mechanize.new

# This endpoint is not "protected" by Kasada
url = "https://plan.sa.gov.au/have_your_say/notified_developments/current_notified_developments/assets/getpublicnoticessummary"
applications = JSON.parse(agent.post(url).body)
applications.each do |application|
  record = {
    "council_reference" => application["applicationID"],
    "address" => application["propertyAddress"],
    "description" => application["developmentDescription"],
    # Not clear whether this page will stay around after the notification period is over
    "info_url" => "https://plan.sa.gov.au/have_your_say/notified_developments/current_notified_developments/submission?aid=#{application['publicNotificationID']}",
    "date_scraped" => Date.today.to_s,
    "on_notice_to" => Date.strptime(application["closingDate"], "%m/%d/%Y").to_s
  }
  ScraperWiki.save_sqlite(['council_reference'], record)
end
