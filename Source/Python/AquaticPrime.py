#!/usr/bin/python
import os
import sha

from base64 import decodestring as b64decode
from base64 import encodestring as b64encode
from binascii import unhexlify as hex2bin

# These are some example generated keys for you convinience, replace the before you start selling your app ;-)
pubKey = u'0xE9DBF6A4F6B443282117C6D5E9255F6735DC45DBCB9FA3CABD0F082689B4A25504A2340E2F2F541BF2CE7987491EC541E8B5496BB6AF235F18B6C31F37CA68B430431E41611E93DCFBE40EB7D3C726E74B9D68B9867706A5E0CBD44E0B8863AAC3D2FDBF3CD57B10C3E90039E966F789CC8CBCB1CEBBD2EB95FF5F05E48F37A3'
privKey = u'0x9BE7F9C34F22D770160FD9E3F0C394EF793D83E7DD1517DC7E0A056F06786C38ADC1780974CA3812A1DEFBAF8614838145CE30F279CA1794BB248214CFDC45CC2EFAD1A84D0B8B442D71623486EC36DF6036A4AD8CD319743E7BCF0ECFEA8D0955B1305E42FE30F042D67A9317F10FF3CD2EDFB1D003896EF7791742199348AB'

def hex2dec(s):
	return int(s, 16)

def dec2hex(n):
	val = "%X" % n
	while len(val) < 256:
		val = '0' + val
	return val

def powmod(x,a,m):
	r=1
	while a>0:
		if a%2==1: r=(r*x)%m
		a=a>>1; x=(x*x)%m
	return r

def reverse(s):
	rs = ""
	for x in s:
		rs = x + rs
	return rs

def getSignature(information):
	
	keys = information.keys()
	keys.sort()
	
	total = u''.join([information[key] for key in keys]).replace(u"'", u"'\\''")
	
	hash = sha.new(total.encode('utf-8')).hexdigest()
	
	paddedHash = '0001'

	for i in range(0, 105):
		paddedHash += 'ff'

	paddedHash += '00' + hash
		
	decryptedSig = hex2dec(paddedHash)
	
	sig = powmod(decryptedSig, hex2dec(privKey), hex2dec(pubKey))
	sig = dec2hex(sig)
	sig = hex2bin(sig)
	sig = b64encode(sig)

	return sig

def licenceData(license_info):
	
	# license_info should be a dict with all the licence items
	
	keys = license_info.keys()
	keys.sort()
	
	signature = getSignature(license_info)
	
	licence_data = u"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	licence_data += u"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
	licence_data += u"<plist version=\"1.0\">\n<dict>\n"

	for key in keys:

		licence_data += u"\t<key>" + key + u"</key>\n"
		licence_data += u"\t<string>" + license_info[key] + u"</string>\n"

	licence_data += u"\t<key>Signature</key>\n"
	licence_data += u"\t<data>" + signature + u"</data>\n"
	licence_data += u"</dict>\n"
	licence_data += u"</plist>\n"
	
	return licence_data

print licenceData({u'name':u'koen'})