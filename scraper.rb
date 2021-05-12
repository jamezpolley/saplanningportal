require 'scraperwiki'
require 'mechanize'
require 'json'
require 'base64'

class Hash
  def has_blank?
    self.values.any?{|v| v.nil? || v.length == 0}
  end
end

# Get the last 14 days
startDate = Date.today - 14
endDate   = Date.today

ajax_url = 'https://plan.sa.gov.au/development_application_register/assets/daregister'

_json = {
  "ActionType" => "select",
  "DataObject" => "PublicRegisterSearch",
  "Config" => "PUBLIC_REGISTER",
  "Params" => [
    {"name" => "LodgedDateStart", "value" => "01/07/2017"},
    {"name" => "LodgedDateEnd", "value" => "18/07/2017"}
  ],
  "SortExpression" => "LodgedNew",
  "RecordNumber" => 0,
  "MaxRecords" => "100"
}
_json['Params'][0]['value'] = startDate.strftime('%Y-%m-%d')
_json['Params'][1]['value'] = endDate.strftime('%Y-%m-%d')
_json['RecordNumber']       = 0
_json['MaxRecords']         = 50
_body = 'payload=' + Base64.strict_encode64(_json.to_json)
_header = { 'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8',
            'Referer'      => 'https://plan.sa.gov.au/development_application_register' }

agent = Mechanize.new
page = agent.post ajax_url, _body, _header

puts page.body

_results = JSON.parse(page.body)
_pages   = ( _results['Count'] / _json['MaxRecords'] ).floor


for i in 0.._pages do
  puts 'Scraping page ' + (i+1).to_s + ' of ' + (_pages+1).to_s

  _json['RecordNumber'] = i * _json['MaxRecords'];

  _body = 'payload=' + Base64.strict_encode64(_json.to_json)

  page = agent.post ajax_url, _body, _header
  puts page.body
  _results = JSON.parse(page.body)

  _results['Values'].each do |result|
    record = {
      'council_reference' => result['FieldValues'][1].to_s,
      'address'           => result['FieldValues'][3].to_s,
      'description'       => result['FieldValues'][4].to_s,
      'info_url'          => 'https://plan.sa.gov.au/development_application_register#view-' + result['FieldValues'][0].to_s + '-' + result['FieldValues'][6].to_s ,
      'comment_url'       => 'https://plan.sa.gov.au/development_application_register',
      'date_scraped'      => Date.today.to_s,
      'date_received'     => Date.parse(result['FieldValues'][5].to_s).to_s,
    }

    unless record.has_blank?
      record['address'] = record['address'] + ', SA'
      puts "Saving record " + record['council_reference'] + ", " + record['address'] + ", " + record['description'] + ", " + record['date_scraped'] + ", " + record['info_url']
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Something not right here: #{record}"
    end
  end
end
