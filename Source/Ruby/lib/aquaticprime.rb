#!/usr/bin/env ruby
# encoding: utf-8

# AquaticPrime is a cryptographically secure licensing method for shareware
# applications. The Ruby implementation currently only generates licenses, and
# is intended for use in online stores.
# Written by John Labovitz <johnl@johnlabovitz.com>.
# Updated by Benjamin Rister <aquaticprime@decimus.net>.

require 'rubygems'

require 'digest/sha1'
require 'plist'
require 'stringio'


module Math

  # Calculates x^a mod m. Useful for public key encryption calculations.
  def self.powmod(x, a, m)
  	r = 1
  	while a > 0
  		if a % 2 == 1
  		  r = (r * x) % m
  	  end
  		a = a >> 1
  		x = (x * x) % m
  	end
  	r
  end

end


# AquaticPrime instances are associated with a given public/private key
# pair, and generate signed license plists for input Hash instances.

class AquaticPrime

  # Returns a new AquaticPrime generator with the given public and private keys.
  # Keys should be provided as hex strings.
  def initialize(pubKey, privKey)
    @pubKey = pubKey
    @privKey = privKey
  end
  
  # Calculates the cryptographic signature for a given Hash, returned as a
  # String.
  # This is generally only of internal interest, but on rare instances
  # clients may wish to calculate this value.
  def signature(information)
	total = information.sort{|a,b| a[0].downcase <=> b[0].downcase || a[0] <=> b[0]}.map{|key,value| value}.join('')
	  
  	hash = Digest::SHA1.hexdigest(total)
  	hash = '0001' + ('ff' * 105) + '00' + hash
		
  	sig = Math.powmod(hash.hex, @privKey.hex, @pubKey.hex)

    # Convert from a big number to a binary string.
    sig = sig.to_s(16)
  	sig = ('0' * (256 - sig.length)) + sig
    sig = sig.unpack('a2' * (sig.length/2)).map { |x| x.hex }.pack('c' * (sig.length/2))

  	sig
  end

  # Returns a String containing a signed license plist based on the given
  # license_info Hash.
  # The result is suitable content for a license file via a download, email
  # attachment, or any other delivery mechanism to the end user.
  def license_data(license_info)
    signed_license_info = license_info.dup
    
    # Sign the license info.
    # If a value in the plist is a StringIO object, it handily ends up as a base64-encoded <data> key
  	signed_license_info['Signature'] = StringIO.new(signature(license_info))
  	
  	signed_license_info.to_plist
  end

end


if $0 == __FILE__
  # testing keys
  pubKey = '0xAAD0DC5705017D4AA1CD3FA194771E97B263E68308DC09D3D9297247D175CCD05DFE410B9426D3C8019BA6B92D34F21B454D8D8AC8CAD2FB37850987C02592012D658911442C27F4D9B050CFA3F7C07FF81CFEEBE33E1E43595B2ACCC2019DC7247829017A91D40020F9D8BF67300CE744263B4F34FF42E3A7BE3CF37C4004EB'
  privKey = '0x71E092E4AE00FE31C1337FC10DA4BF0FCC4299ACB092B137E61BA185364E888AE9542B5D0D6F37DAABBD19D0C8CDF6BCD8DE5E5C85DC8CA77A58B1052AC3B6AA5C7EA2E58BD484050184D2E241CFCB1D6AB4AC8617499056060833D8F6699B9C54E3BAA36123AFD5B4DDE6F2ADFC08F6970C3BA5C80B9A0A04CB6C6B73DD512B'
  
  aquatic_prime = AquaticPrime.new(pubKey, privKey)
  
  easy_license = {
  	'Email' => 'user@email.com',
  	'Name' => 'User'
  }
  puts 'EASY LICENSE RESULTS:'
  puts aquatic_prime.license_data(easy_license)
  
  hard_license = {
  	'Email' => 'user@email.com',
  	'Name' => 'Üsér Diacriticà',
  	'lowercase key' => 'Keys should be sorted case-insensitive'
  }
  puts 'HARD LICENSE RESULTS:'
  puts aquatic_prime.license_data(hard_license)
end