<?php

// includes
require("Config.php");
require("AquaticPrime.php");

$log; global $log;
$format = "m/d/Y H:i:s"; global $format;

class BMTXMLParser 
{
	var $tag_name;
	var $tag_data;
	
	function BMTXMLParser() 
    {
		$tag_name = NULL;
		$tag_data = array();
    }
    
	function startElement($parser, $name, $attrs) 
	{
		$this->tag_name = $name;
	}
	
	function endElement($parser, $name) 
	{
		$this->tag_name = NULL;
	}
	
	function characterData($parser, $data) 
	{
		if($this->tag_name != NULL) 
		{
			$this->tag_data[$this->tag_name] = $data;
		}
	}    
	           
	function parse($data) 
	{
		$xml_parser = xml_parser_create();
		xml_set_object($xml_parser, $this);                        
		xml_parser_set_option($xml_parser, XML_OPTION_CASE_FOLDING, false);
		xml_set_element_handler($xml_parser, "startElement", "endElement");
		xml_set_character_data_handler($xml_parser, "characterData");
		$success = xml_parse($xml_parser, $data, true);
		
		if(!$success) 
		{
			$this->tag_data['error'] = sprintf("XML error: %s at line %d", xml_error_string(xml_get_error_code($xml_parser)), xml_get_current_line_number($xml_parser));
		}
		
		xml_parser_free($xml_parser);
		
		return($success);
	}     
	          
	function getElement($tag) 
	{
		return($this->tag_data[$tag]);
	}  
}

// parse the XML data
$bmtparser = new BMTXMLParser();

// Work around a PHP 5.2.2 bug preventing POST data from reaching the script.
// See <http://bugs.php.net/bug.php?id=41293> for details.
if ($_SERVER["REQUEST_METHOD"] == "POST") {
	if ( !isset( $HTTP_RAW_POST_DATA ) ) {
		$HTTP_RAW_POST_DATA = file_get_contents("php://input");
	}
}

if($bmtparser->parse($HTTP_RAW_POST_DATA)) 
{
    echo '<?xml version="1.0" encoding="utf-8"?>';
    echo '<response>';
    echo '<registrationkey>';
	echo '<keydata></keydata>';
    echo '</registrationkey>';
    echo '</response>';
}
else 
{
    echo '<?xml version="1.0" encoding="utf-8"?>';
    echo '<response>';
    echo '<registrationkey>';
	echo '<errorcode>1</errorcode>';
	echo '<errormessage>' . $bmtparser->getElement('error') . '</errormessage>';
    echo '</registrationkey>';
    echo '</response>';
    
    die();
} 

// generate the serial

// Create our license dictionary to be signed
$dict = array("Product" => $bmtparser->getElement('productname'),
              "Name" => $bmtparser->getElement('registername'),
              "Email" => $bmtparser->getElement('email'),
              "OrderID" => $bmtparser->getElement('orderid'));

$license = licenseDataForDictionary($dict, $key, $privateKey);

// send the e-mail with that serial

$name = $bmtparser->getElement('registername');
$email = $bmtparser->getElement('email');

$to = $email;

$from = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $from);
$subject = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $subject);
$message = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $message);
$licenseName = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $licenseName);
$bcc = str_replace(array("##NAME##", "##EMAIL##"), array($name, $email), $bcc);

sendMail($to, $from, $subject, $message, $license, $licenseName, $bcc);

?> 
