<?php
/** 
  * AquaticPrime Kagi payment tester
  * Sends test transactions to AquaticPrime Kagi
  * @author Lucas Newman, Aquatic
  * @copyright Copyright &copy; 2005 Lucas Newman
  * @license http://www.opensource.org/licenses/bsd-license.php BSD License
  */

// AquaticPrime Kagi Remote Post System Tester
?><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" 
"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html>
<head>
	<title>AquaticPrime Kagi Test</title>
	<style type="text/css">
	body {
	   text-align: center;
	   background: lightblue;
	}
    form {
        padding: 10px;
    }
	</style>
</head>
<body>
	<form action="AquaticPrimeKagi.php" method="post">
		<p>
            Password: <input type="text" name="ACG:Password" /><br />
            Product Name: <input type="text" name="ACG:ProductName" /><br />
            Purchaser Name: <input type="text" name="ACG:PurchaserName" /><br />
            Purchaser Email: <input type="text" name="ACG:PurchaserEmail" /><br />
            Quantity: <input type="text" name="ACG:QuantityOrdered" /><br />
            Date: <input type="text" name="ACG:DateProcessed" /><br />
            
            <input type="hidden" name="ACG:TransactionID" value="<? echo rand(); ?>" />
            <input type="hidden" name="ACG:Request" value="Generate" />
            <input type="hidden" name="ACG:InputVersion" value="0201" />
            <input type="hidden" name="ACG:Flags" value="test=1" />
            <input type="submit" />
        </p>
	</form>
</body>
</html>