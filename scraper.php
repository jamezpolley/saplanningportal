<?php
require_once 'vendor/autoload.php';
require_once 'vendor/openaustralia/scraperwiki/scraperwiki.php';

use PGuardiario\PGBrowser;

date_default_timezone_set('Australia/Sydney');

# Default to 'thisweek', use MORPH_PERIOD to change to 'thismonth', 'lastmonth' or specific year for data recovery
switch(getenv('MORPH_PERIOD')) {
    case 'thismonth' :
        $period = 'thismonth';
        $period_start = date("01/m/Y");
        $period_end   = date("d/m/Y");
        break;
    case 'lastmonth' :
        $period = 'lastmonth';
        $period_start = date("01/m/Y", strtotime("-1 month"));
        $period_end   = date("d/m/Y", strtotime("last day of last month"));
        break;
    default         :
        if ( is_numeric(getenv('MORPH_PERIOD')) ) {
            // database starting from 2003
            $year = (int) getenv('MORPH_PERIOD');
            $year >= 2003 && $year <= date("Y") ?: $year = date("Y");
            $period = (string) $year;
            $period_start = "01/01/" .$year;
            $period_end   = "31/12/" .$year;
        } else {
            $period = 'thisweek';
            $period_start = date("d/m/Y", strtotime("-7 days"));
            $period_end   = date("d/m/Y");
        }
        break;
}
print "Getting data for `" .$period. "`, changable via MORPH_PERIOD environment\n";

$ajax_url = 'http://apps.planning.sa.gov.au/AjaxDataService/DataHandler.ashx';
$info_url = 'http://www.saplanningportal.sa.gov.au/public_register';            // #view-58896-LDE
$payload  = 'eyJBY3Rpb25UeXBlIjoic2VsZWN0IiwiRGF0YU9iamVjdCI6IlB1YmxpY1JlZ2lzdGVyU2VhcmNoIiwiUGFyYW1zIjpbeyJuYW1lIjoiTG9kZ2VkRGF0ZVN0YXJ0IiwidmFsdWUiOiIwMS8wNy8yMDE3In0seyJuYW1lIjoiTG9kZ2VkRGF0ZUVuZCIsInZhbHVlIjoiMTgvMDcvMjAxNyJ9XSwiU29ydEV4cHJlc3Npb24iOiJMb2RnZWROZXciLCJSZWNvcmROdW1iZXIiOjAsIk1heFJlY29yZHMiOiIxMDAifQ==';

// construct the basic browser
$b = new \PGuardiario\PGBrowser();
$_json = json_decode(base64_decode($payload));
$_json->Params[0]->value = $period_start;	      // Start
$_json->Params[1]->value = $period_end;	        // End
$_json->RecordNumber = 0;
$_json->MaxRecords = 1000;                      // default 100 but increased to 1000, less pagination
$_body = 'payload=' .base64_encode(json_encode($_json));

$_header = [ 'Content-Type:application/x-www-form-urlencoded; charset=UTF-8',
						 'Referer: http://www.saplanningportal.sa.gov.au/public_register',
					 ];

// get the total pages between those dates specified
$page = $b->post($ajax_url, $_body, $_header);
$_results = json_decode($page->body);
$_pages   = floor($_results->Count / $_json->MaxRecords);

// loop thru all those pages
for ($i=0; $i <= $_pages; $i++) {
    print "Scraping page " .($i+1). " of " .($_pages+1). "\n";
    $_json->RecordNumber = $i * $_json->MaxRecords;

    $_body = 'payload=' .base64_encode(json_encode($_json));
    $page = $b->post($ajax_url, $_body, $_header);
    $_results = json_decode($page->body);

    foreach ($_results->Values as $result) {
        $council_reference = preg_replace('/\s+/', ' ', trim($result->FieldValues[0]));

        $date_received = explode('/', $result->FieldValues[5]);
        $date_received = $date_received[2] .'-'. $date_received[1] .'-'. $date_received[0];

        $address = trim($result->FieldValues[2]);

        // if address field blank, skip this iteration
        if ( strlen($address) < 5 ) {
            print "Skipping DA `" . $council_reference . "` beacuse of blank or short address.\n";
            continue;
        }

        $application = [
            'council_reference' => $council_reference,
            'address'           => $address . ', SA',
            'description'       => preg_replace('/\s+/', ' ', trim($result->FieldValues[3])),
            'info_url'          => $info_url . "#view-" .trim($result->FieldValues[6]). "-" .trim($result->FieldValues[7]),
            'comment_url'       => $info_url,
            'date_scraped'      => date('Y-m-d'),
            'date_received'     => date('Y-m-d', strtotime($date_received))
        ];

        # Check if record exist, if not, INSERT, else do nothing
        $existingRecords = scraperwiki::select("* from data where `council_reference`='" . $application['council_reference'] . "'");
        if (count($existingRecords) == 0) {
            print ("Saving record " .$application['council_reference']. " - " .$application['address']. "\n");
//             print_r ($application);
            scraperwiki::save(array('council_reference'), $application);
        } else {
            print ("Skipping already saved record " . $application['council_reference'] . "\n");
        }
    }
}


