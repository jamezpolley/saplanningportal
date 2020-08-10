require 'scraperwiki'
require 'mechanize'
require 'json'
require 'base64'


class Hash
  def has_blank?
    self.values.any?{|v| v.nil? || v.length == 0}
  end
end


case ENV['MORPH_PERIOD']
when 'thismonth'
  period    = 'This Month'
  startDate = (Date.today) - (Date.today.mday) + 1
  endDate   = ((Date.today >> 1) - (Date.today.mday))
when 'lastmonth'
  period    = 'Last Month'
  startDate = (Date.today << 1) - (Date.today << 1).mday + 1
  endDate   = (Date.today) - (Date.today.mday)
else
  period    = 'Last 14 Days'
  startDate = Date.today - 14
  endDate   = Date.today
end
puts "Getting '" + period + "' data, changeable using the MORPH_PERIOD environment variable"


## ajax_url = 'https://apps.planning.sa.gov.au/AjaxDataService/DataHandler.ashx'
## payload  = 'eyJBY3Rpb25UeXBlIjoic2VsZWN0IiwiRGF0YU9iamVjdCI6IlB1YmxpY1JlZ2lzdGVyU2VhcmNoIiwiUGFyYW1zIjpbeyJuYW1lIjoiTG9kZ2VkRGF0ZVN0YXJ0IiwidmFsdWUiOiIwMS8wNy8yMDE3In0seyJuYW1lIjoiTG9kZ2VkRGF0ZUVuZCIsInZhbHVlIjoiMTgvMDcvMjAxNyJ9XSwiU29ydEV4cHJlc3Npb24iOiJMb2RnZWROZXciLCJSZWNvcmROdW1iZXIiOjAsIk1heFJlY29yZHMiOiIxMDAifQ=='
ajax_url = 'https://plan.sa.gov.au/development_application_register/assets/daregister'
payload  = 'eyJBY3Rpb25UeXBlIjoic2VsZWN0IiwiRGF0YU9iamVjdCI6IlB1YmxpY1JlZ2lzdGVyU2VhcmNoIiwiQ29uZmlnIjoiUFVCTElDX1JFR0lTVEVSIiwiUGFyYW1zIjpbeyJuYW1lIjoiTG9kZ2VkRGF0ZVN0YXJ0IiwidmFsdWUiOiIwMS8wNy8yMDE3In0seyJuYW1lIjoiTG9kZ2VkRGF0ZUVuZCIsInZhbHVlIjoiMTgvMDcvMjAxNyJ9XSwiU29ydEV4cHJlc3Npb24iOiJMb2RnZWROZXciLCJSZWNvcmROdW1iZXIiOjAsIk1heFJlY29yZHMiOiIxMDAifQ==' 

## Update JSON fields
_json = JSON.parse(Base64.decode64(payload))
_json['Params'][0]['value'] = startDate.strftime('%d/%m/%Y')
_json['Params'][1]['value'] = endDate.strftime('%d/%m/%Y')
_json['RecordNumber']       = 0
_json['MaxRecords']         = 50
_body = 'payload=' + Base64.strict_encode64(_json.to_json)
_header = { 'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8',
            'Referer'      => 'https://plan.sa.gov.au/development_application_register' }
##             'Referer'      => 'https://www.saplanningportal.sa.gov.au/current_planning_system/development_assessment/public_register' }

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
      'address'           => result['FieldValues'][4].to_s,
      'description'       => result['FieldValues'][5].to_s,
      'info_url'          => 'https://plan.sa.gov.au/development_application_register#view-' + result['FieldValues'][0].to_s + '-' + result['FieldValues'][8].to_s ,
      'comment_url'       => 'https://plan.sa.gov.au/development_application_register',
      'date_scraped'      => Date.today.to_s,
      'date_received'     => Date.parse(result['FieldValues'][7].to_s).to_s,
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
