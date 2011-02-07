#tag Class
Class AquaticPrime
	#tag Method, Flags = &h0
		Sub AddToBlacklist(newHash as string)
		  
		  mblacklist.append newHash
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Constructor()
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(publicKey as string, privateKey as string = "")
		  
		  #if targetMacOS or targetLinux
		    
		    Soft Declare Sub ERR_load_crypto_strings Lib CryptoLib ()
		    
		    ERR_load_crypto_strings
		    
		    self.SetKey publicKey, privateKey
		    
		  #endif
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Destructor()
		  
		  #if targetMacOS or targetLinux
		    
		    Soft Declare Sub ERR_free_strings Lib CryptoLib ()
		    Soft Declare Sub RSA_free Lib CryptoLib (r as Ptr)
		    
		    ERR_free_strings
		    
		    if rsaKey <> nil then
		      RSA_free(rsaKey)
		    end if
		    
		  #endif
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function DictionaryForLicenseData(licenseData as string) As dictionary
		  
		  #if targetMacOS or targetLinux
		    Soft Declare Function RSA_public_decrypt Lib CryptoLib (flen as integer, from as Ptr, mto as Ptr, rsa as Ptr, padding as integer) As integer
		    Soft Declare Function ERR_error_string Lib CryptoLib (e as UInt32, buf as Ptr) As CString
		    Soft Declare Function ERR_get_error Lib CryptoLib () As UInt32
		    Soft Declare Function SHA1_Init Lib CryptoLib (c as Ptr) As integer
		    Soft Declare Function SHA1_Update Lib CryptoLib (c as Ptr, data as CString, mlen as UInt32) As integer
		    Soft Declare Function SHA1_Final Lib CryptoLib (md as Ptr, c as Ptr) As integer
		  #endif
		  
		  dim x as new xmlDocument
		  dim topDoc as xmlElement
		  dim dict as xmlElement
		  dim keyArray(-1) as string
		  dim valueArray(-1) as string
		  dim node as XMLNode
		  dim element as XMLElement
		  dim n as integer
		  
		  const kLicenseDataNotValidError = "Invalid license data"
		  
		  // Make sure public key is set up
		  if rsaKey = nil or rsaKey.UInt32Value(16) = 0 then
		    self.SetError "RSA key is invalid"
		    return nil
		  end if
		  
		  // Traverse the XML structure and load key, value pairs in arrays
		  try
		    x.loadXml(licenseData)
		    
		    // Do some sanity checks on the XML
		    if x.documentElement is nil or x.documentElement.childCount <> 1 then
		      self.SetError kLicenseDataNotValidError
		      return nil
		    end if
		    
		    topDoc = x.documentElement
		    if topDoc.LocalName <> "plist" or topDoc.firstChild is nil or not topDoc.firstChild isA XMLElement then
		      self.SetError kLicenseDataNotValidError
		      return nil
		    end if
		    
		    dict = XMLElement(topDoc.firstChild)
		    if dict.LocalName <> "dict" or dict.childCount = 0 then
		      self.SetError kLicenseDataNotValidError
		      return nil
		    end if
		    
		    node = dict.firstChild
		    
		    do
		      if not node isA XMLElement then
		        return nil
		      end if
		      element = XMLElement(node)
		      if element.childCount <> 1 or not element.firstChild isA XMLTextNode then
		        self.SetError kLicenseDataNotValidError
		        return nil
		      end if
		      
		      if element.LocalName = "key" then
		        keyArray.append element.firstChild.value
		      elseif element.LocalName = "string" or element.LocalName = "data" then
		        valueArray.append element.firstChild.value
		      end if
		      node = element.nextSibling
		    loop until node is nil
		    
		  catch err as RuntimeException
		    self.SetError kLicenseDataNotValidError
		    return nil
		  end try
		  
		  // Get the signature
		  dim sigBytes as new MemoryBlock(128)
		  sigBytes.stringValue(0, 128) = DecodeBase64(valueArray(keyArray.indexOf("Signature")))
		  
		  // Decrypt the signature - should get 20 bytes back
		  #if targetMacOS or targetLinux
		    dim checkDigest as new MemoryBlock(20)
		    if RSA_public_decrypt(128, sigBytes, checkDigest, rsaKey, RSA_PKCS1_PADDING) <> SHA_DIGEST_LENGTH then
		      self.SetError ERR_error_string(ERR_get_error(), nil)
		      return nil
		    end if
		  #endif
		  
		  // Remove the Signature element from arrays
		  dim elementNumber as integer= keyArray.indexOf("Signature")
		  keyArray.remove elementNumber
		  valueArray.remove elementNumber
		  
		  // Get the license hash
		  n = SHA_DIGEST_LENGTH-1
		  dim hashCheck as string
		  for hashIndex as integer = 0 to n
		    hashCheck = hashCheck + lowercase(right("0"+hex(checkDigest.byte(hashIndex)), 2))
		  next
		  
		  // Store the license hash in case we need it later
		  self.SetHash hashCheck
		  
		  // Make sure the license hash isn't on the blacklist
		  if mblacklist.indexOf(hash) <> -1 then
		    return nil
		  end if
		  
		  // Sort the keys so we always have a uniform order
		  keyArray.sortWith(valueArray)
		  
		  // Setup up the hash context
		  #if targetMacOS or targetLinux
		    dim ctx as new memoryBlock(96)
		    call SHA1_Init(ctx)
		  #endif
		  
		  // Update the SHA1 stuff
		  #if targetMacOS or targetLinux
		    n = ubound(valueArray)
		    for i as integer = 0 to n
		      call SHA1_Update(ctx, valueArray(i), lenB(valueArray(i)))
		    next
		    dim digest as new MemoryBlock(SHA_DIGEST_LENGTH)
		    call SHA1_Final(digest, ctx)
		  #endif
		  
		  // Check if the signature is a match
		  n = SHA_DIGEST_LENGTH-1
		  for i as integer = 0 to n
		    if bitwise.bitXor(checkDigest.byte(i), digest.byte(i)) <> 0 then
		      return nil
		    end if
		  next
		  
		  // If it's a match, we return the dictionary; otherwise, we never reach this
		  
		  // Build a RB dictionary to return
		  dim retDict as new dictionary
		  n = ubound(keyArray)
		  for i as integer = 0 to n
		    retDict.value(keyArray(i)) = valueArray(i)
		  next
		  
		  return retDict
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function DictionaryForLicenseFile(licenseFile as folderItem) As dictionary
		  
		  // Read the XML file
		  dim licenseStream as binaryStream
		  dim data as string
		  
		  if licenseFile = nil or not licenseFile.exists or not licenseFile.isReadable then
		    return nil
		  end if
		  
		  licenseStream = BinaryStream.Open(licenseFile)
		  if licenseStream = nil then
		    return nil
		  end if
		  
		  data = licenseStream.read(licenseStream.length)
		  licenseStream.close
		  
		  return DictionaryForLicenseData(data)
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function LicenseDataForDictionary(dict as dictionary) As string
		  
		  #if targetMacOS or targetLinux
		    Soft Declare Function SHA1 Lib CryptoLib (d as Ptr, n as UInt32, md as Ptr) As Ptr
		    Soft Declare Function RSA_size Lib CryptoLib (RSA as Ptr) as Integer
		    Soft Declare Function RSA_private_encrypt Lib CryptoLib (flen as Integer, from as Ptr, mto as Ptr, rsa as Ptr, padding as integer) as integer
		    Soft Declare Function ERR_error_string Lib CryptoLib (e as UInt32, buf as Ptr) As CString
		    Soft Declare Function ERR_get_error Lib CryptoLib () As UInt32
		  #endif
		  
		  // Make sure we have a good key
		  if rsaKey = nil or rsaKey.UInt32Value(16) = 0 or rsaKey.UInt32Value(24) = 0 then
		    self.SetError "RSA key is invalid"
		    return ""
		  end if
		  
		  // Grab all values from the dictionary
		  dim keyArray(-1) as string
		  dim dictData as new memoryBlock(1)
		  dim n as integer = dict.count-1
		  for i as integer = 0 to n
		    keyArray.append dict.key(i)
		  next
		  
		  // Sort the keys so we always have a uniform order
		  keyArray.Sort
		  dim oldSize as integer = 0
		  for i as integer = 0 to n
		    dim curValue as string = dict.value(keyArray(i))
		    dictData.size = oldSize+lenB(curValue)
		    dictData.StringValue(oldSize, lenB(curValue)) = curValue
		    oldSize = dictData.size
		  next
		  
		  // Hash the data
		  #if targetMacOS or targetLinux
		    dim digest as new memoryBlock(20)
		    call SHA1(dictData, dictData.size, digest)
		  #endif
		  
		  // Create the signature from 20 byte hash
		  #if targetMacOS or targetLinux
		    dim rsaLength as integer = RSA_size(rsaKey)
		    dim signature as new memoryBlock(rsaLength)
		    dim bytes as integer = RSA_private_encrypt(20, digest, signature, rsaKey, RSA_PKCS1_PADDING)
		  #endif
		  
		  if bytes = -1 then
		    #if targetMacOS or targetLinux
		      self.SetError ERR_error_string(ERR_get_error(), nil)
		    #endif
		    return ""
		  end if
		  
		  // Create plist data (XML document)
		  dim x as new XMLDocument
		  dim comment as XMLComment= x.createComment("DOCTYPE plist PUBLIC ""-//Apple//DTD PLIST 1.0//EN"" ""http://www.apple.com/DTDs/PropertyList-1.0.dtd""")
		  x.appendChild comment
		  dim plist as XMLNode = x.appendChild(x.createElement("plist"))
		  dim attr as XMLAttribute = x.createAttribute("version")
		  attr.value = "1.0"
		  plist.setAttributeNode(attr)
		  dim dictXML as XMLNode = plist.appendChild(x.createElement("dict"))
		  
		  n = ubound(keyArray)
		  for i as integer = 0 to n
		    dim key as XMLNode = dictXML.appendChild(x.createElement("key"))
		    key.appendChild x.createTextNode(keyArray(i))
		    dim value as XMLNode = dictXML.appendChild(x.createElement("string"))
		    value.appendChild x.createTextNode(dict.value(keyArray(i)))
		  next
		  
		  dim key as XMLNode = dictXML.appendChild(x.createElement("key"))
		  key.appendChild x.createTextNode("Signature")
		  dim value as XMLNode = dictXML.appendChild(x.createElement("data"))
		  value.appendChild x.createTextNode(ReplaceLineEndings(EncodeBase64(signature.stringValue(0, bytes), 68), endOfLine.UNIX))
		  
		  // Reformat XML for pretty printing
		  dim XMLoutput as string = ReplaceAll(x.toString, "><", ">"+endOfLine.UNIX+"<")
		  XMLoutput = Replace(Replace(XMLoutput, "<!--", "<!"), "-->", ">")
		  XMLoutput = ReplaceAll(XMLoutput, "<key>", chr(9)+"<key>")
		  XMLoutput = ReplaceAll(XMLoutput, "<string>", chr(9)+"<string>")
		  XMLoutput = ReplaceAll(XMLoutput, "<data>", chr(9)+"<data>"+endOfLine.UNIX)
		  XMLoutput = Replace(XMLoutput, "</data>", endOfLine.UNIX+chr(9)+"</data>")
		  dim dataStart as integer = instr(XMLoutput, "<data>")+6
		  dim dataEnd as integer = instr(XMLoutput, "="+endOfLine.UNIX)-2
		  XMLoutput = left(XMLoutput, dataStart-1)_
		  +replaceAll(mid(XMLoutput, dataStart, dataEnd-dataStart), endOfLine.UNIX, endOfLine.UNIX+chr(9))_
		  +mid(XMLoutput, dataEnd)_
		  +endOfLine.UNIX
		  
		  return XMLoutput
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function MemAddress(m as memoryBlock) As UInt32
		  
		  dim mAddr as new memoryBlock(4)
		  
		  mAddr.ptr(0) = m
		  
		  return mAddr.UInt32Value(0)
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetBlacklist(hashArray() as string)
		  
		  dim u as Integer = UBound(hashArray)
		  redim mblacklist(u)
		  
		  for i as Integer = 0 to u
		    mblacklist(i) = hashArray(i)
		  next
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub SetError(err as string)
		  
		  aqError = err
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub SetHash(hashString as string)
		  
		  mhash = hashString
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetKey(key as string, privateKey as string = "")
		  
		  #if targetMacOS or targetLinux
		    
		    Soft Declare Sub RSA_free Lib CryptoLib (r as Ptr)
		    Soft Declare Function RSA_new Lib CryptoLib () As Ptr
		    Soft Declare Function BN_dec2bn Lib CryptoLib (a as UInt32, str as CString) As integer
		    Soft Declare Function BN_hex2bn Lib CryptoLib (a as UInt32, str as CString) As integer
		    Soft Declare Function ERR_get_error Lib CryptoLib () As UInt32
		    Soft Declare Function ERR_error_string Lib CryptoLib (e as UInt32, buf as Ptr) As CString
		    
		    // Must have public modulus, private key is optional
		    if key = "" then
		      self.SetError "Empty public key parameter"
		      return
		    end if
		    
		    if rsaKey <> nil then
		      RSA_free(rsaKey)
		    end if
		    
		    #if targetMacOS or targetLinux
		      rsaKey = RSA_new()
		    #endif
		    
		    // We are using the constant public exponent e = 3
		    call BN_dec2bn(MemAddress(rsaKey)+20, "3")
		    
		    // Determine if we have hex or decimal values
		    dim result as integer
		    
		    if left(key, 2) = "0x" then
		      result = BN_hex2bn(MemAddress(rsaKey)+16, mid(key, 3))
		    else
		      result = BN_dec2bn(MemAddress(rsaKey)+16, key)
		    end if
		    
		    if result = 0 then
		      self.SetError ERR_error_string(ERR_get_error(), nil)
		      return
		    end if
		    
		    // Do the private portion if it exists
		    if privateKey <> "" then
		      if left(privateKey, 2) = "0x" then
		        result = BN_hex2bn(MemAddress(rsaKey)+24, mid(privateKey, 3))
		      else
		        result = BN_dec2bn(MemAddress(rsaKey)+24, privateKey)
		      end if
		      
		      if result = 0 then
		        self.SetError ERR_error_string(ERR_get_error(), nil)
		        return
		      end if
		    end if
		    
		  #endif
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function VerifyLicenseData(data as string) As boolean
		  
		  return (self.DictionaryForLicenseData(data) <> nil)
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function VerifyLicenseFile(file as folderItem) As boolean
		  
		  return (self.DictionaryForLicenseFile(file) <> nil)
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function WriteLicenseFileForDictionary(dict as dictionary, file as folderItem) As boolean
		  
		  dim licenseFile as string = self.LicenseDataForDictionary(dict)
		  
		  if licenseFile = "" then
		    return false
		  end if
		  
		  if file = nil or not file.isWriteable then
		    return false
		  end if
		  
		  dim licenseStream as BinaryStream = BinaryStream.Create(file, true)
		  if licenseStream = nil then
		    return false
		  end if
		  
		  licenseStream.write(licenseFile)
		  licenseStream.close
		  
		  return true
		  
		End Function
	#tag EndMethod


	#tag Note, Name = Legal
		
		AquaticPrime.rbp
		AquaticPrime REAL Studio (REALbasic) Implementation
		
		Copyright (c) 2010, Massimo Valle
		All rights reserved.
		
		derived and adapted from the original C/Objective-C impementation
		Copyright (c) 2005, Lucas Newman
		All rights reserved.
		
		Redistribution and use in source and binary forms, with or without modification,
		are permitted provided that the following conditions are met:
		- Redistributions of source code must retain the above copyright notice,
		this list of conditions and the following disclaimer.
		- Redistributions in binary form must reproduce the above copyright notice,
		this list of conditions and the following disclaimer in the documentation and/or
		other materials provided with the distribution.
		- Neither the name of the Aquatic nor the names of its contributors may be used to
		endorse or promote products derived from this software without specific prior written permission.
		
		THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
		IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
		FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
		CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
		DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
		DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
		IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
		OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
	#tag EndNote


	#tag Property, Flags = &h21
		Private aqError As string
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  
			  return mhash
			End Get
		#tag EndGetter
		hash As string
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  
			  #if targetMacOS
			    
			    Soft Declare Function BN_bn2hex Lib CryptoLib (a as UInt32) As CString
			    
			    if rsaKey = nil or rsaKey.UInt32Value(16) = 0 then
			      return ""
			    end if
			    
			    return BN_bn2hex(MemAddress(rsaKey)+16)
			    
			  #endif
			End Get
		#tag EndGetter
		Key As string
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  
			  return aqError
			  
			End Get
		#tag EndGetter
		LastError As string
	#tag EndComputedProperty

	#tag Property, Flags = &h21
		Private mblacklist() As string
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mhash As string
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  
			  #if targetMacOS
			    
			    Soft Declare Function BN_bn2hex Lib CryptoLib (a as UInt32) As CString
			    
			    if rsaKey = nil or rsaKey.UInt32Value(24) = 0 then
			      return ""
			    end if
			    
			    return BN_bn2hex(MemAddress(rsaKey)+24)
			    
			  #endif
			End Get
		#tag EndGetter
		PrivateKey As string
	#tag EndComputedProperty

	#tag Property, Flags = &h21
		Private rsaKey As memoryBlock
	#tag EndProperty


	#tag Constant, Name = CryptoLib, Type = String, Dynamic = False, Default = \"libcrypto.dylib", Scope = Private
		#Tag Instance, Platform = Mac OS, Language = Default, Definition  = \"libcrypto.dylib"
		#Tag Instance, Platform = Linux, Language = Default, Definition  = \"libcrypto"
	#tag EndConstant

	#tag Constant, Name = RSA_PKCS1_PADDING, Type = Double, Dynamic = False, Default = \"1", Scope = Private
	#tag EndConstant

	#tag Constant, Name = SHA_DIGEST_LENGTH, Type = Double, Dynamic = False, Default = \"20", Scope = Private
	#tag EndConstant


	#tag ViewBehavior
		#tag ViewProperty
			Name="hash"
			Group="Behavior"
			Type="string"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Key"
			Group="Behavior"
			Type="string"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="LastError"
			Group="Behavior"
			Type="string"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="PrivateKey"
			Group="Behavior"
			Type="string"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			InheritedFrom="Object"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
