utils = require './utils'
checkSignature = require './checkSignature'
Database = require './database'
_ = require 'underscore'

# MWAHAHAHA!
When = require 'when'
Promise = When.promise

# Security checks (⌐■_■)

userMinTimestamps = {}

checkSignatureValidity = (userId, kind, newTimestamp) ->
  userMinTimestamps[userId] = {} if not userMinTimestamps[userId]
  return false if userMinTimestamps[userId][kind]? > newTimestamp
  userMinTimestamps[userId][kind] = newTimestamp
  true

papersPlease =
  #
  #   88""Yb 888888  dP"Yb  88   88 888888 .dP"Y8 888888
  #   88__dP 88__   dP   Yb 88   88 88__   `Ybo."   88
  #   88"Yb  88""   Yb b dP Y8   8P 88""   o.`Y8b   88
  #   88  Yb 888888  `"YoYo `YbodP' 888888 8bodP'   88
  #
  request: (request) -> new Promise (resolve) ->
    # return true if request.origin is 'http://localhost:3000'
    # return false
    resolve request

  #
  #      db    88   88 888888 88  88
  #     dPYb   88   88   88   88  88
  #    dP__Yb  Y8   8P   88   888888
  #   dP""""Yb `YbodP'   88   88  88
  #
  auth: (umc) -> new Promise (resolve) ->
    if umc.message.type isnt 'handshake' and not umc.user?.id
      throw new Error 'Unauthorized before handshake'

    resolve umc

  #
  #   88""Yb 888888  dP"Yb  88   88 88 88""Yb 888888 8888b.
  #   88__dP 88__   dP   Yb 88   88 88 88__dP 88__    8I  Yb
  #   88"Yb  88""   Yb b dP Y8   8P 88 88"Yb  88""    8I  dY
  #   88  Yb 888888  `"YoYo `YbodP' 88 88  Yb 888888 8888Y"
  #
  required: (umc) -> new Promise (resolve) ->
    if not umc.message.data
      throw new Error 'No data'

    # check required fields
    requiredCommonFields = [ 'id', 'type', 'data' ]
    requiredFields = []

    if not utils.checkRequiredFields umc.message, requiredCommonFields
      throw new Error 'Missing required common fields'

    switch umc.message.type
      when 'handshake'
        requiredFields = [
          'data.userId',
          'data._userId_sign',
          'data.userRole',
          'data._userRole_sign' ]
      when 'message'
        requiredFields = [ 'session', 'data.message' ]
      when 'join'
        requiredFields = [ 'session' ]
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
    if not utils.checkRequiredFields umc.message, requiredFields
      throw new Error 'Missing required type fields'

    # check if userid is equal to id
    userId = umc.user.id
    if umc.message.type is 'handshake' and not umc.user.id?
      userId = umc.message.data.userId

    if "#{userId}" isnt umc.message.id.split('.')[0]
      throw new Error 'user.id incoherent with message.id'

    resolve umc

  #
  #   88  88    db    88b 88 8888b.  .dP"Y8 88  88    db    88  dP 888888
  #   88  88   dPYb   88Yb88  8I  Yb `Ybo." 88  88   dPYb   88odP  88__
  #   888888  dP__Yb  88 Y88  8I  dY o.`Y8b 888888  dP__Yb  88"Yb  88""
  #   88  88 dP""""Yb 88  Y8 8888Y"  8bodP' 88  88 dP""""Yb 88  Yb 888888
  #
  handshake: (umc) -> new Promise (resolve) ->
    if not umc.message.data
      throw new Error 'No data'

    data = umc.message.data

    if not checkSignature data.userId, data._userId_sign
      throw new Error 'No signature for userId'

    if not checkSignature data.userRole, data._userRole_sign
      throw new Error 'No signature for userRole'

    uid = data.userId
    userIdTs = data._userId_sign.substring 44
    userRoleTs = data._userRole_sign.substring 44

    if not checkSignatureValidity uid, 'userId', userIdTs
      throw new Error 'Signature invalid for userId'
    if not checkSignatureValidity uid, 'userRole', userRoleTs
      throw new Error 'Signature invalid for userRole'

    resolve umc

  #
  #    88888  dP"Yb  88 88b 88
  #       88 dP   Yb 88 88Yb88
  #   o.  88 Yb   dP 88 88 Y88
  #   "bodP'  YbodP  88 88  Y8
  #
  join: (umc) -> new Promise (resolve) ->
    if not umc.message.data
      throw new Error 'No data'

    sessions = Database.userSessions.get umc.user.id
    # check if session is in user sessions allowed
    if umc.message.session not in sessions
      throw new Error 'Forbidden session'

    resolve umc

  #
  #   8b    d8 888888 .dP"Y8 .dP"Y8    db     dP""b8 888888
  #   88b  d88 88__   `Ybo." `Ybo."   dPYb   dP   `" 88__
  #   88YbdP88 88""   o.`Y8b o.`Y8b  dP__Yb  Yb  "88 88""
  #   88 YY 88 888888 8bodP' 8bodP' dP""""Yb  YboodP 888888
  #
  message: (umc) -> new Promise (resolve) ->
    if not umc.message.data
      throw new Error 'No data'

    sessions = Database.userSessions.get umc.user.id
    # check if session is in user sessions allowed
    if umc.message.session not in sessions
      throw new Error 'Forbidden session'

    resolve umc

  checkSignatureValidity: checkSignatureValidity

module.exports = exports = papersPlease