require "mechanize"
require "json"
require "scraperwiki"

agent = Mechanize.new

# This endpoint is not "protected" by Kasada
url = "https://plan.sa.gov.au/have_your_say/notified_developments/current_notified_developments/assets/getpublicnoticessummary"
applications = JSON.parse(agent.post(url).body)
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
  page = agent.post("https://plan.sa.gov.au/have_your_say/notified_developments/current_notified_developments/assets/getpublicnoticedetail", aid: application["applicationID"])
  detail = JSON.parse(page.body)
  record["comment_email"] = detail["email"]

  puts "Saving record #{record['council_reference']}, #{record['address']}"
  ScraperWiki.save_sqlite(['council_reference'], record)
end
