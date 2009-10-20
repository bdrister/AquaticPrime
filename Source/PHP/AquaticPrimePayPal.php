<?php
/** 
  * AquaticPrime PayPal payment processor
  * Generates license files and emails them after handling PayPal payments
  * @author Lucas Newman, Aquatic
  * @copyright Copyright &copy; 2005 Lucas Newman
  * @license http://www.opensource.org/licenses/bsd-license.php BSD License
  */

require("Config.php");
require("AquaticPrime.php");

$tx_token = $_GET['tx'];
$req = "cmd=_notify-synch&tx=$tx_token&at=$auth_token";

// POST back to PayPal system to validate
$header	 = "POST /cgi-bin/webscr HTTP/1.0\r\n";
$header .= "Content-Type: application/x-www-form-urlencoded\r\n";
$header .= "Content-Length: " . strlen($req) . "\r\n\r\n";
$fp = fsockopen('www.paypal.com', 80, $errno, $errstr, 30);

if (!$fp) 
{
	// Put in a URL here to redirect on error
	header("Location: $error_url");
	die;
}

fputs($fp, $header.$req);

// read the body data 
$res = '';
$headerdone = false;
while (!feof($fp))
{
	$line = fgets($fp, 1024);
	if (strcmp($line, "\r\n") == 0) 
	{
		// read the header
		$headerdone = true;
	}
	else if ($headerdone)
	{
		// header has been read. now read the contents
		$res .= $line;
	}
}

// parse the data
$lines = explode("\n", $res);
$keyarray = array();

if (strcmp ($lines[0], "FAIL") == 0) 
{
	// Put in a URL here to redirect back on error
	header("Location: $error_url");
	die;
}

for ($i = 1; $i < count($lines); $i++)
{
	list($lineKey, $lineValue) = explode("=", $lines[$i]);
	$keyarray[urldecode($lineKey)] = urldecode($lineValue);
}

$product = $keyarray['item_name'];
$name = $keyarray['first_name']." ".$keyarray['last_name'];
$email = $keyarray['payer_email'];
$amount = $keyarray['mc_gross'];
$count = $keyarray['quantity'];
// RFC 2822 formatted date
$timestamp = date("r", strtotime($keyarray['payment_date']));
$transactionID = $keyarray['txn_id'];

// Create our license dictionary to be signed
$dict = array("Product" => $product,
			  "Name" => $name,
			  "Email" => $email,
			  "Licenses" => $count,
			  "Timestamp" => $timestamp,
			  "TransactionID" => $transactionID);

$license = licenseDataForDictionary($dict, $key, $privateKey);

$to = $email;

$from = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $from);
$subject = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $subject);
$message = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $message);
$licenseName = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $licenseName);
$bcc = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $bcc);

sendMail($to, $from, $subject, $message, $license, $licenseName, $bcc);

fclose ($fp);

header("Location: $redirect_url");
?>
