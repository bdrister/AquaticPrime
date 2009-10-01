<?php
/** 
  * AquaticPrime PHP Config
  * Configuration for web server license generation
  * @author Lucas Newman, Aquatic
  * @copyright Copyright &copy; 2005 Lucas Newman
  * @license http://www.opensource.org/licenses/bsd-license.php BSD License
  */

// ----CONFIG----

// When pasting keys here, don't include the leading "0x" that AquaticPrime Developer adds.
$key = "---YOUR APP KEY---";
$privateKey = "---YOUR APP PRIVATE KEY---";

$domain = "---YOUR DOMAIN---";
$product = "---YOUR PRODUCT---";
$download = "http://$domain/---YOUR DOWNLOAD PATH---";

// These fields below should be customized for your application.  You can use ##NAME## in place of the customer's name and ##EMAIL## in place of his/her email
$from = "support@$domain";
$subject = "$product License For ##NAME##";
$message =
"Hello ##NAME##!  Here's your license for $product.

If you have not already downloaded $product please do so now: <$download>

---YOUR INSTALL INSTRUCTIONS--- to register $product.

Thanks,
---YOUR NAME HERE---";

// It's a good idea to BCC your own email here so you can have an order history
$bcc = "orders@$domain";

// This is the name of the license file that will be attached to the email
$licenseName = "##NAME##.---YOUR LICENSE EXTENSION---";

// ---KAGI ONLY CONFIG----

$kagiPassword = "testPassword";


// ---PAYPAL ONLY CONFIG----

// Your PDT authorization token
$auth_token = "AUTH TOKEN HERE";
// Put in a URL here to redirect back to after the transaction
$redirect_url = "http://$domain/thanks.html";
$error_url = "http://$domain/error.html";


// ---ESELLERATE ONLY CONFIG----
// Secret text set up in your eSellerate publisher account
$order_notice_secret = "my secret esellerate string";
// List of eSellerate SKUs that should be processed by AquaticPrime.  Included because things like
// eCDs will come through as a separate SKU, but you probably don't want to run the order through
// AquaticPrime.  Anything not in this list will be ignored.
$aquaticPrimeSKUs = array(
		"SKU1234567890"	
		);
		
		
// ---MYSQL CONFIG----

// Database of registrations
$db_host        = "--DATABASE HOST HERE --";
$db_user        = "--DATABASE USER HERE--";
$db_password    = "--DATABASE PW HERE--";
$db_name        = "--DATABASE NAME HERE--";

?>
