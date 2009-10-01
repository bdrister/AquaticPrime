<?php
/** 
  * AquaticPrime Kagi payment processor
  * Generates license files and emails them after handling Kagi payments
  * @author Lucas Newman, Aquatic
  * @copyright Copyright &copy; 2005 Lucas Newman
  * @license http://www.opensource.org/licenses/bsd-license.php BSD License
  */

// AquaticPrime Kagi Remote Post System Handler
// This implementation is based on data culled from http://www.kagi.com/acg/Spec/KRPS_Supplier_Spec.pdf

require("Config.php");
require("AquaticPrime.php");

// Here we calculate the password hash so we can be sure it's Kagi that's accessing this script
// Make sure to set the shared secret to something besides 'testPassword' in Config.php
$password = $kagiPassword.$_POST["ACG:TransactionID"].$_POST["ACG:ProductName"].$_POST["ACG:UnitPayment"].$_POST["ACG:DateProcessed"].$_POST["ACG:QuantityOrdered"].$_POST["ACG:LicenseType"];
$passwordHash = sha1(strtolower($password));

// Kagi-recommended sanity checking
if ($_POST["ACG:Password"] != $passwordHash && $_POST["ACG:Password"] != $kagiPassword) {
	header("Content-type: text/text");
	echo "kagiRemotePostStatus=BAD, message=Password incorrect.\r\n\r\n"; die;
}
if ($_POST["ACG:Request"] != "Generate") {
	header("Content-type: text/text");
	echo "kagiRemotePostStatus=BAD, message=Only generation is supported.\r\n\r\n"; die;
}
// Use + 0 to convert the version string to an integer
if ($_POST["ACG:InputVersion"] + 0 < 0200)
{
	header("Content-type: text/text");
	echo "kagiRemotePostStatus=BAD, message=KRPS version is too old.\r\n\r\n"; die;
}

// Some values from Kagi that we choose to add to the license
$product = urldecode($_POST["ACG:ProductName"]);
$name = urldecode($_POST["ACG:PurchaserName"]);
$email = urldecode($_POST["ACG:PurchaserEmail"]);
$count = urldecode($_POST["ACG:QuantityOrdered"]);
// RFC 2822 formatted date
$timestamp = date("r", strtotime(urldecode($_POST["ACG:DateProcessed"])));
$transactionID = urldecode($_POST["ACG:TransactionID"]);

// Create our license dictionary to be signed
$dict = array("Product" => $product,
			  "Name" => $name,
			  "Email" => $email,
			  "Licenses" => $count,
			  "Timestamp" => $timestamp,
			  "TransactionID" => $transactionID);

$license = licenseDataForDictionary($dict, $key, $privateKey);

$to = $email;

// Handle test orders by setting the To: email to the BCC: email
if (stristr(urldecode($_POST["ACG:Flags"]), "test=1"))
	$to = $bcc;

$from = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $from);
$subject = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $subject);
$message = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $message);
$licenseName = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $licenseName);
$bcc = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $bcc);

sendMail($to, $from, $subject, $message, $license, $licenseName, $bcc);

header("Content-type: text/text");
echo "kagiRemotePostStatus=GOOD, message=Transaction completed.\r\n\r\n";

?>