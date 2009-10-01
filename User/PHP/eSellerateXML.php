<?php
/* Functions for parsing eSellerate XML order notices.  Adapted from an
   unsupported example provided by eSellerate support.

How it is called:
	EsellSample.php
		POSTed with XML Order stream

Action:
	This page extracts the serial number for each order line and adds it to the database.
	The database has a table called Licenses which contains fields called
	SKU, KeyCode, Quantity, and Date.
Return:
	Nothing. No one is listening. (Some interesting debug messages are currently displayed.)

*/

/***************************************************
Beginning of XML parsing functions.

We build an array matching the structure of the incoming
XML data. Each sub-tag is a named array element. The data
for each tag is stored in the ["_data"] entry.

The one special handler for the eSellerate data
is the management of the ORDERLINES tag. That is set up
as a numbered array corresponding to however many order lines
there are, stored in $nOrderLines.

****************************************************/

$XmlData = array();		// The results are stored in this array
$nOrderLines = 0;		// The number of order lines is stored here
$stack = array();		// Temporary variable used during parsing

function & curElement()
{
	global $XmlData, $stack;
	$cur = & $XmlData;

	foreach ($stack as $node)
	{
		$tmp = & $cur[$node];
		$cur = & $tmp;
	}

	return $cur;
}

function AddNode($name)
{
	$cur = & curElement();
	if (!array_key_exists($name, $cur))
		$cur[$name] = array();
}

function startElement($parser, $name, $attrs) 
{
	global $stack;
	global $nOrderLines;

	AddNode($name);
	$stack[] = $name;

	if ($name == "ORDERLINES")
	{
		AddNode($nOrderLines);
		$stack[] = $nOrderLines;
		++$nOrderLines;
	}
}

function endElement($parser, $name)
{
	global $stack;

	if ($name == "ORDERLINES")
		array_pop($stack);		// Remove the index

	$popped = array_pop($stack);
	assert('($popped == $name)');
}

function characterData($parser, $data) 
{
	$cur = & curElement();
	$cur["_data"] .= $data;
}

/***************************************************
Utility functions
***************************************************/

// Msg - Display a message if $DbgMsg is set
	$DbgMsg = TRUE;		// Set this to FALSE to suppress messages
function Msg($msg)
{
	global $DbgMsg;

	if ($DbgMsg)
		echo $msg;
}

// TryOpenDb and CloseDb - Open and close the database.
// Change the username, password, and database to the correct values for your database
	$DbLink = FALSE;
	$DbError = "";

function TryOpenDb()
{
	global $DbLink;
	global $DbError;

	global $db_host;
	global $db_user;
	global $db_password;
	global $db_name;

    /* Connecting, selecting database */
	$DbLink = mysql_connect($db_host, $db_user, $db_password);

	if (!$DbLink)
	{
		$DbError = mysql_error();
		return FALSE;
	}

    if (!mysql_select_db($db_name))
	{
		$DbError = mysql_error();
		CloseDb();
		return FALSE;
	}

	return $DbLink;
}

function CloseDb()
{
	global $DbLink;

	if ($DbLink)
	{
		mysql_close($DbLink);
		$DbLink = FALSE;
	}
}

// ReportFatalError - Display a message, close the database, and terminate
function ReportFatalError($Error)
{
	global $DbLink;
	Msg($Error);
	if ($DBLink) {
		mysql_query("ROLLBACK");
	}
	CloseDb();
	exit();
}


?>

