utils = require './utils'
checkSignature = require './checkSignature'
Database = require './database'
SessionReader = require './sessionReader'
_ = require 'underscore'

# MWAHAHAHA!
When = require 'when'
Promise = When.promise

# Security checks (⌐■_■)

userMinTimestamps = {}

papersPlease =
  #
  #   88""Yb 888888  dP"Yb  88   88 888888 .dP"Y8 888888
  #   88__dP 88__   dP   Yb 88   88 88__   `Ybo."   88
  #   88"Yb  88""   Yb b dP Y8   8P 88""   o.`Y8b   88
  #   88  Yb 888888  `"YoYo `YbodP' 888888 8bodP'   88
  #
  request: (request) -> new Promise (resolve, reject) ->
    # origin = request.origin
    # cookies = request.cookies
    session = request.cookies.filter((i) -> i.name is 'PLAY_SESSION')[0]?.value
    session = SessionReader session
    if not session.id? or not session.role?
      reject 'No user id nor role'
    # Check origin against allowed values list
    else if request.origin not in ['http://localhost:3000']
      reject 'Invalid Origin'
    else
      resolve request, session

  #
  #      db    88   88 888888 88  88
  #     dPYb   88   88   88   88  88
  #    dP__Yb  Y8   8P   88   888888
  #   dP""""Yb `YbodP'   88   88  88
  #
  auth: (umc) -> new Promise (resolve) ->
    resolve umc

  #
  #    dP""b8  dP"Yb  88b 88 88b 88 888888  dP""b8 888888
  #   dP   `" dP   Yb 88Yb88 88Yb88 88__   dP   `"   88
  #   Yb      Yb   dP 88 Y88 88 Y88 88""   Yb        88
  #    YboodP  YbodP  88  Y8 88  Y8 888888  YboodP   88
  #
  connect: (umc) -> new Promise (resolve) ->
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

    if "#{userId}" isnt umc.message.id.split('.')[0]
      throw new Error 'user.id incoherent with message.id'

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

module.exports = exports = papersPlease