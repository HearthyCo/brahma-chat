utils = require './utils'
checkSignature = require './checkSignature'
_ = require 'underscore'

# Security checks (⌐■_■)

userMinTimestamps = {}

papersPlease =
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
          'data.userRole',
          'data._userRole_sign',
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
    userId = object.data.userId if object.type is 'handshake' and not userId?
    return false if "#{userId}" isnt object.id.split('.')[0]

    return true

  session: (object, uid) ->
    return false if not object.data or not uid
    data = object.data

    if not checkSignature JSON.stringify(data.sessions), data._sessions_sign
      return false

    sessionsTs = data._sessions_sign.substring 44
    return false if not @checkSignatureValidity uid, 'sessions', sessionsTs

    return true

  handshake: (object) ->
    return false if not object.data
    data = object.data

    return false if not checkSignature data.userId, data._userId_sign

    if not checkSignature JSON.stringify(data.sessions), data._sessions_sign
      return false

    uid = data.userId
    userIdTs = data._userId_sign.substring 44
    userRoleTs = data._userRole_sign.substring 44
    sessionsTs = data._sessions_sign.substring 44
    return false if not @checkSignatureValidity uid, 'userId', userIdTs
    return false if not @checkSignatureValidity uid, 'userRole', userRoleTs
    return false if not @checkSignatureValidity uid, 'sessions', sessionsTs

    return true

  message: (object, sessions) ->
    return false if not object.data
    data = object.data

    # check if session is in user sessions allowed
    return false if (object.session not in sessions)

    return true

  checkSignatureValidity: (userId, kind, newTimestamp) ->
    userMinTimestamps[userId] = {} if not userMinTimestamps[userId]
    return false if userMinTimestamps[userId][kind]? > newTimestamp
    userMinTimestamps[userId][kind] = newTimestamp
    true

module.exports = exports = papersPlease