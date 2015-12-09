crypto = require 'crypto'
_ = require 'underscore'

config = require './config'

module.exports = exports = (cookie) ->
  if cookie
    # b5ed65f56a49b34f28633f1882d6f7103bfcf83c-id=2
    [hash, message] = cookie.split('-', 2)
    secret = config.secret

    myHash = crypto
      .createHmac("SHA1", secret)
      .update(message)
      .digest('hex')

    if hash isnt myHash
      console.warn 'Rejected bad session:', cookie
      return {}

    _.object _.compact _.map message.split('&'), (item) ->
      if item then item.split '='
  else
    console.warn 'Rejected no-cookie session'
    return {}
