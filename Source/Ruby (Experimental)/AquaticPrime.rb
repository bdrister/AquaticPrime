#!/usr/bin/env ruby

# Ruby implementation of AquaticPrime license generation.
# Written by John Labovitz <johnl@johnlabovitz.com>.

require 'digest/sha1'
require 'plist'
require 'base64'


module Math
  
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


class AquaticPrime

  def initialize(pubKey, privKey)
    @pubKey = pubKey
    @privKey = privKey
  end
  
  def signature(information)
	
  	total = information.sort.map { |key, value| value }.join('')
	  
  	hash = Digest::SHA1.hexdigest(total)
  	hash = '0001' + ('ff' * 105) + '00' + hash
		
  	sig = Math.powmod(hash.hex, @privKey.hex, @pubKey.hex)

    # Convert from a big number to a binary string.
    sig = sig.to_s(16)
  	sig = ('0' * (256 - sig.length)) + sig
    sig = sig.unpack('a2' * (sig.length/2)).map { |x| x.hex }.pack('c' * (sig.length/2))

  	sig
  end

  def licence_data(license_info)
    signed_license_info = license_info.dup
    
    # Sign the license info.
    # If a value in the plist is a StringIO object, it handily ends up as a base64-encoded <data> key
  	signed_license_info['Signature'] = StringIO.new(signature(license_info))
  	
  	signed_license_info.to_plist
  end

end


if $0 == __FILE__
  
  # sample keys
  pubKey = '0xE9DBF6A4F6B443282117C6D5E9255F6735DC45DBCB9FA3CABD0F082689B4A25504A2340E2F2F541BF2CE7987491EC541E8B5496BB6AF235F18B6C31F37CA68B430431E41611E93DCFBE40EB7D3C726E74B9D68B9867706A5E0CBD44E0B8863AAC3D2FDBF3CD57B10C3E90039E966F789CC8CBCB1CEBBD2EB95FF5F05E48F37A3'
  privKey = '0x9BE7F9C34F22D770160FD9E3F0C394EF793D83E7DD1517DC7E0A056F06786C38ADC1780974CA3812A1DEFBAF8614838145CE30F279CA1794BB248214CFDC45CC2EFAD1A84D0B8B442D71623486EC36DF6036A4AD8CD319743E7BCF0ECFEA8D0955B1305E42FE30F042D67A9317F10FF3CD2EDFB1D003896EF7791742199348AB'
  
  aquatic_prime = AquaticPrime.new(pubKey, privKey)
  
  license = {
    'name' => 'koen'
  }
  
  puts aquatic_prime.licence_data(license)
end