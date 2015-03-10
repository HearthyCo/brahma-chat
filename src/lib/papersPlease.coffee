utils = require './utils'
checkSignature = require './checkSignature'
_ = require 'underscore'

# Security checks (⌐■_■)
papersPlease = {
  request: (request) ->
    # return true if request.origin is 'http://localhost:3000'
    # return false
    return true

  required: (object, userId) ->
    # check required fields
    requiredCommonFields = [ 'id', 'type', 'data' ]
    requiredFields = []

    return false if not utils.checkRequiredFields object, requiredCommonFields

    switch object.type
      when 'session'
        requiredFields = [
          'data.sessions',
          'data._sessions_sign'
        ]
      when 'handshake'
        requiredFields = [
          'data.userId',
          'data._userId_sign',
          'data.sessions',
          'data._sessions_sign' ]
      when 'message'
        requiredFields = [ 'session', 'data.message' ]
      when 'attachment'
        requiredFields = [
          'session',
          'data.message',
          'data.href',
          'data.type',
          'data.size' ]
      when 'ping'
        requiredFields = [ 'data.message' ]

    requiredFields = _.union requiredCommonFields, requiredFields
    return false if not utils.checkRequiredFields object, requiredFields

    # check if userid is equal to id
    userId = object.data.userId if object.type is 'handshake' && not userId?
    return false if userId + '' isnt object.id.split('.')[0]

    return true

  session: (object) ->
    return false if not object.data
    data = object.data

    if not checkSignature JSON.stringify(data.sessions), data._sessions_sign
      return false

    return true

  handshake: (object) ->
    return false if not object.data
    data = object.data

    return false if not checkSignature data.userId, data._userId_sign

    if not checkSignature JSON.stringify(data.sessions), data._sessions_sign
      return false

    return true

  message: (object, sessions) ->
    return false if not object.data
    data = object.data

    # check if session is in user sessions allowed
    return false if not (object.session in sessions)

    return true
}

module.exports = exports = papersPlease