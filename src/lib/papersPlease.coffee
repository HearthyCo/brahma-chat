utils = require './utils'
checkSignature = require './checkSignature'
Database = require './database'
_ = require 'underscore'

Config = require './config'

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
  request: (request) -> new Promise (resolve) ->
    # return true if request.origin is 'http://localhost:3000'
    # return false
    resolve request

  auth: (umc) -> new Promise (resolve) ->
    if umc.message.type isnt 'handshake' and not umc.user?.id
      throw new Error 'Unauthorized before handshake'

    resolve umc

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

  join: (umc) -> new Promise (resolve) ->
    if not umc.message.data
      throw new Error 'No data'

    if Config.options.requireSessionAccess
      sessions = Database.userSessions.get umc.user.id
      # check if session is in user sessions allowed
      if umc.message.session not in sessions
        throw new Error 'Forbidden session'

    resolve umc

  message: (umc) -> new Promise (resolve) ->
    if not umc.message.data
      throw new Error 'No data'

    if Config.options.requireSessionAccess
      sessions = Database.userSessions.get umc.user.id
      # check if session is in user sessions allowed
      if umc.message.session not in sessions
        throw new Error 'Forbidden session'

    resolve umc

  checkSignatureValidity: checkSignatureValidity

module.exports = exports = papersPlease