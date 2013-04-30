crypto = require 'crypto'
bigint = require 'bigint'

# example keys
pubKey = 'E9DBF6A4F6B443282117C6D5E9255F6735DC45DBCB9FA3CABD0F082689B4A25504A2340E2F2F541BF2CE7987491EC541E8B5496BB6AF235F18B6C31F37CA68B430431E41611E93DCFBE40EB7D3C726E74B9D68B9867706A5E0CBD44E0B8863AAC3D2FDBF3CD57B10C3E90039E966F789CC8CBCB1CEBBD2EB95FF5F05E48F37A3'
privKey = '9BE7F9C34F22D770160FD9E3F0C394EF793D83E7DD1517DC7E0A056F06786C38ADC1780974CA3812A1DEFBAF8614838145CE30F279CA1794BB248214CFDC45CC2EFAD1A84D0B8B442D71623486EC36DF6036A4AD8CD319743E7BCF0ECFEA8D0955B1305E42FE30F042D67A9317F10FF3CD2EDFB1D003896EF7791742199348AB'

powmod = (x, a, m) ->
  r = bigint 1
  while a.gt bigint 0
    if a.mod(bigint 2).eq bigint 1
      r = r.mul(x).mod m
    a = a.shiftRight 1
    x = x.mul(x).mod m
  r

getSignature = (licensee, priv, pub) ->
  total = (licensee[key] for key in (k for k of licensee).sort()).join ''
  hash = crypto.createHash 'sha1'
  hash.update total, 'utf8'
  digest = hash.digest 'hex'
  paddedHash = '0001'
  for i in [0..104]
    paddedHash += 'ff'
  paddedHash += '00' + digest

  powmod(bigint(paddedHash, 16),
    bigint(priv, 16), bigint(pub, 16)).toBuffer().toString 'base64'

module.exports = getSignature

if require.main is module
  console.log getSignature {name: 'koen'}, privKey, pubKey
