<?php
/** 
  * AquaticPrime eSellerate payment processor
  * Generates license files and emails them after handling eSellerate XML Order Notices
  * @author Tom Harrington, Atomic Bird (some portions adapted from examples by Lucas Newman)
  * @copyright Copyright &copy; 2006 Tom Harrington
  * @license http://www.opensource.org/licenses/bsd-license.php BSD License
  */

require("Config.php");
require("AquaticPrime.php");
require("eSellerateXML.php");

// Esellerate preview orders will not be processed unless $debug is 1.
$debug = 0;

	/***************************************************
	The main body of the module. Note that the web server
	must be configured to allow access to raw post data.
	This can be done by adding the line:
	php_flag always_populate_raw_post_data on
	to .htaccess on Apache.
	
	Note: I have sometimes found that this is not necessary,
	but I'm not sure why. Add it if you run into a problem.
	It makes the $HTTP_RAW_POST_DATA variable valid.
	***************************************************/

	// Work around a PHP 5.2.2 bug preventing POST data from reaching the script.
	// See <http://bugs.php.net/bug.php?id=41293> for details.
	if ($_SERVER["REQUEST_METHOD"] == "POST") {
		if ( !isset( $HTTP_RAW_POST_DATA ) ) {
			$HTTP_RAW_POST_DATA = file_get_contents("php://input");
		}
	}

	$xml_parser = xml_parser_create();
	xml_set_element_handler($xml_parser, "startElement", "endElement");
	xml_set_character_data_handler($xml_parser, "characterData");

	if (!xml_parse($xml_parser, $HTTP_RAW_POST_DATA, TRUE))
	{
		$msg = sprintf("XML error: %s at line %d",
			xml_error_string(xml_get_error_code($xml_parser)),
			xml_get_current_line_number($xml_parser));
		xml_parser_free($xml_parser);
		ReportFatalError($msg);
	}

	xml_parser_free($xml_parser);

	// We have all the data in the $XmlData array

	// Check the secret text
	if ($XmlData["ORDERNOTICEDS"]["ORDERINFO"]["ORDER_NOTICE_SECRET"]["_data"] != $order_notice_secret) {
		ReportFatalError("Invalid order notice secret\n");
	}

	// Ignore Preview orders
	if (($debug == 0) && ($XmlData["ORDERNOTICEDS"]["ORDERINFO"]["STATUS"]["_data"] == "PREVIEW"))
	{
		ReportFatalError("No processing of preview order except in debug mode.\n");
	}

	// For Aquatic Prime we really need the date and time (in case someone orders more than one copy
	// the same day), so the date from eSellerate won't cut it.
	$sn_date = strftime("%Y-%m-%d %H:%m:%S");
	// Process each order line
	for ($i = 0; $i < $nOrderLines; ++$i)
	{
		// Now do the AquaticPrime stuff
		if (in_array($XmlData["ORDERNOTICEDS"]["ORDERLINES"][$i]["SKU_ID"]["_data"], $aquaticPrimeSKUs)) {
			$product = $XmlData["ORDERNOTICEDS"]["ORDERLINES"][$i]["SKU_TITLE"]["_data"];
			$name = $XmlData["ORDERNOTICEDS"]["ORDERLINES"][$i]["REGISTRATION_NAME"]["_data"];
			$email = $XmlData["ORDERNOTICEDS"]["ORDERINFO"]["EMAIL"]["_data"];
			$unit_price = $XmlData["ORDERNOTICEDS"]["ORDERLINES"][$i]["UNIT_PRICE"]["_data"];
			$count = $XmlData["ORDERNOTICEDS"]["ORDERLINES"][$i]["QUANTITY"]["_data"];
			// eSellerate only gives you the date, not the time (so we don't do RFC 2822 formatting here).
			$transactionID = $orderNumber;
			// Create our license dictionary to be signed
			$dict = array("Product" => $product,
					  "Name" => $name,
					  "Email" => $email,
					  "Licenses" => $count,
					  "Timestamp" => $sn_date,
					  "TransactionID" => $transactionID);
			$license = licenseDataForDictionary($dict, $key, $privateKey);

			$to = $email;

			$from = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $from);
			$subject = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $subject);
			$message = str_replace(array("##NAME##", "##EMAIL##", "##LICENSES##"), array($name, $email, $count), $message);
			$licenseName = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $licenseName);
			$bcc = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $bcc);

			sendMail($to, $from, $subject, $message, $license, $licenseName, $bcc);
		}

	}

?>
