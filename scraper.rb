require 'scraperwiki'
require 'mechanize'
require 'json'
require 'base64'

class Hash
  def has_blank?
    self.values.any?{|v| v.nil? || v.length == 0}
  end
end

# Get the last 28 days
startDate = Date.today - 28
endDate   = Date.today

ajax_url = 'https://plan.sa.gov.au/development_application_register/assets/daregister'

_json = {
  "ActionType" => "select",
  "DataObject" => "PublicRegisterSearch",
  "Config" => "PUBLIC_REGISTER",
  "Params" => [
    {"name" => "LodgedDateStart", "value" => startDate.strftime('%Y-%m-%d')},
    {"name" => "LodgedDateEnd", "value" => endDate.strftime('%Y-%m-%d')}
  ],
  "SortExpression" => "LodgedNew",
  "RecordNumber" => 0,
  "MaxRecords" => 100
}
_body = 'payload=' + Base64.strict_encode64(_json.to_json)
_header = { 'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8',
            'Referer'      => 'https://plan.sa.gov.au/development_application_register' }

agent = Mechanize.new
page = agent.post ajax_url, _body, _header

_results = JSON.parse(page.body)
_pages   = ( _results['Count'] / _json['MaxRecords'] ).floor

for i in 0.._pages do
  puts 'Scraping page ' + (i+1).to_s + ' of ' + (_pages+1).to_s

  _json['RecordNumber'] = i * _json['MaxRecords'];

  _body = 'payload=' + Base64.strict_encode64(_json.to_json)

  page = agent.post ajax_url, _body, _header

  _results = JSON.parse(page.body)

  # Pick out fields by name rather than index
  codes = _results["Fields"]["Fields"].map{|f| f["FieldCode"]}
  council_reference_index = codes.find_index("AppId")
  address_index = codes.find_index("Addr")
  description_index = codes.find_index("DevDesc")
  date_received_index = codes.find_index("Lodged")

  app_id_index = codes.find_index("AppId")
  base_index = codes.find_index("Base")

  _results['Values'].each do |result|
    record = {
      'council_reference' => result['FieldValues'][council_reference_index].to_s,
      'address'           => result['FieldValues'][address_index].to_s,
      'description'       => result['FieldValues'][description_index].to_s,
      'info_url'          => 'https://plan.sa.gov.au/development_application_register#view-' + result['FieldValues'][app_id_index].to_s + '-' + result['FieldValues'][base_index].to_s ,
      'comment_url'       => 'https://plan.sa.gov.au/development_application_register',
      'date_scraped'      => Date.today.to_s,
      'date_received'     => Date.parse(result['FieldValues'][date_received_index].to_s).to_s,
    }

    unless record.has_blank?
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Something not right here: #{record}"
    end
  end
end
