_ = require 'underscore'
crypto = require 'crypto'

getSignature = (licensee) ->
  total = _(licensee).chain().keys().invoke('toLowerCase').value().sort().join ''