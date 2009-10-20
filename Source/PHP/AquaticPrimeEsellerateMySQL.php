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

// Fields from OrderInfo you want in the database.  Customize as needed, only ORDER_NUMBER is required.
$orderInfoFields = array("CUSTOMER_IP",
		"ORDER_NUMBER",
		"STATUS",
		"TRAN_DATE",
		"FIRST_NAME",
		"LAST_NAME",
		"COMPANY",
		"ADDRESS1",
		"ADDRESS2",
		"CITY",
		"STATE",
		"POSTAL",
		"COUNTRY",
		"PHONE",
		"EMAIL",
		"SHIP_FIRST_NAME",
		"SHIP_LAST_NAME",
		"SHIP_COMPANY",
		"SHIP_ADDRESS1",
		"SHIP_ADDRESS2",
		"SHIP_CITY",
		"SHIP_STATE",
		"SHIP_POSTAL",
		"SHIP_COUNTRY",
		"CONTACT_ME",
		"ORDER_DISCOUNT",
		"SHIP_WEIGHT",
		"SHIP_METHOD",
		"SHIP_AMOUNT",
		"ESELLER_ID",
		"ESELLER_NAME",
		"METHOD",
		"SUB_METHOD",
		"COUPON_ID",
		"TRACKING_ID",
		"VAT_COUNTRY",
		"CURRENCY_CODE",
		"AFFILIATE_ID",
		"AFFILIATE_NAME",
		"PORTAL_ID",
		"PORTAL_NAME",
		"CUSTOM_0",
		"CUSTOM_1",
		"CUSTOM_2",
		"CUSTOM_3",
		"CUSTOM_4",
		"CUSTOM_5",
		"CUSTOM_6",
		"CUSTOM_7",
		"CUSTOM_8",
		"CUSTOM_9"
		);

$orderLinesFields = array("SKU_ID",
		"SKU_TITLE",
		"SHORT_DESCRIPTION",
		"QUANTITY",
		"UNIT_PRICE",
		"PLATFORM",
		"REGISTRATION_NAME",
		"PROMPTED_VALUE",
		"REGISTRATION_OTHER",
		"EXPIRATION_DATE",
		"SERIAL_NUMBER",
		"PROCESSING_FEE",
		"SALES_TAX_AMOUNT",
		"AFFILIATE_COMMISION",
		"VOLUME_DISCOUNT",
		"CROSS_SELL_DISCOUNT",
		"UP_SELL_GROUP_ID",
		"UP_SELL_PARENT_SKU_ID"
		);

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
	
	// We will open a MySql database and store the serial numbers
	if (!TryOpenDb())
	{
		ReportFatalError($DbError);
	}

	// The tables in eSellerate.sql are type InnoDB, so we can have the safety of transactions.
	// The corresponding COMMIT is at the end of this file.  The ROLLBACK, if necessary, is over in ReportFatalError().
	mysql_query("BEGIN");

	//$date = date("Y/m/d");
	// Fix up the transaction date to give MySQL something it likes.
	$tran_date_str = $XmlData["ORDERNOTICEDS"]["ORDERINFO"]["TRAN_DATE"]["_data"];
	$tran_date_stamp = strtotime($tran_date_str);
	$tran_date_for_sql = strftime("%Y-%m-%d", $tran_date_stamp);
	$XmlData["ORDERNOTICEDS"]["ORDERINFO"]["TRAN_DATE"]["_data"] = $tran_date_for_sql;

	// Write the OrderInfo stuff to the database
	$orderNumber = 	$XmlData["ORDERNOTICEDS"]["ORDERINFO"]["ORDER_NUMBER"]["_data"];
	// First check and see whether the order's already in the database.
	$sqlResult = mysql_query("SELECT ORDER_NUMBER from OrderInfo WHERE ORDER_NUMBER=\"$orderNumber\"");
	if (!$sqlResult) {
		ReportFatalError(mysql_error());
	}
	$numRows = mysql_num_rows($sqlResult);
	mysql_free_result($sqlResult);
	if ($numRows > 0) {
		ReportFatalError("Order $orderNumber is already in the database\n");
	}
	// It wasn't there?  OK, put it there.
	// Build a query string
	$queryStringValues = array();
	foreach ($orderInfoFields as $currentField) {
		$queryStringValues[] = "\"" . mysql_real_escape_string($XmlData["ORDERNOTICEDS"]["ORDERINFO"][$currentField]["_data"]) . "\"";
	}
	$queryString = "INSERT INTO OrderInfo (" . join(", ", $orderInfoFields) . ")" .
				" VALUES (" . join(", ", $queryStringValues) . ")";
	if ($debug == 1) {
		echo "$queryString\n";
	}
	// Do the insert
	$sqlResult = mysql_query($queryString);
	if (!$sqlResult) {
		ReportFatalError(mysql_error());
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
			if ($name == "") {
				$name = $XmlData["ORDERNOTICEDS"]["ORDERINFO"]["FIRST_NAME"]["_data"] . " " .
					$XmlData["ORDERNOTICEDS"]["ORDERINFO"]["LAST_NAME"]["_data"];
			}
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

			// Note that the database size for SERIAL_NUMBER was raised from 255 (eSellerate's size) to
			// a MySQL TEXT field to fit alternate registration schemes.
			$XmlData["ORDERNOTICEDS"]["ORDERLINES"][$i]["SERIAL_NUMBER"]["_data"] = $license;

			$to = $email;

			$from = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $from);
			$subject = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $subject);
			$message = str_replace(array("##NAME##", "##EMAIL##", "##LICENSES##"), array($name, $email, $count), $message);
			$licenseName = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $licenseName);
			$bcc = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $bcc);

			sendMail($to, $from, $subject, $message, $license, $licenseName, $bcc);
		}

		// Build a query string
		$queryStringValues = array();
		foreach ($orderLinesFields as $currentField) {
			$queryStringValues[] = "\"" . mysql_real_escape_string($XmlData["ORDERNOTICEDS"]["ORDERLINES"][$i][$currentField]["_data"]) . "\"";
		}
		$queryString = "INSERT INTO OrderLines (" . join(", ", $orderLinesFields) . ", ORDER_NUMBER, SN_DATE)" .
					" VALUES (" . join(", ", $queryStringValues) . ", \"$orderNumber\", \"$sn_date\")";
		if ($debug == 1) {
			echo "$queryString\n";
		}
		// Do the insert

		$sqlResult = mysql_query($queryString);
		if (!$sqlResult) {
			ReportFatalError(mysql_error());
		}

	}

	mysql_query("COMMIT");
	CloseDb();

?>
