Config = require './config'
redis = require 'redis'
Database = require './database'
PapersPlease = require './papersPlease'
utils = require './utils'

eventHandler = require('got-events')()

LOG = "Chat >"

###
  REDIS -------------------------------------------------------------
###

redisClient = null
redisConnect = (cfg, callback) ->
  callback = callback or (err) ->
    console.error LOG, 'Redis error', err if err

  ###coffeelint-variable-scope-ignore###
  redisClient = redis.createClient cfg.port, cfg.host, {}
  redisClient.on 'error', callback
  redisClient.on 'connect', callback

module.exports = actions =
  connect: (_Config = Config) ->
    # Open Redis connection
    redisConnect _Config.redis, (err) ->
      if err
        console.error LOG, 'Redis error', err
      else
        console.info LOG, 'Redis connected'

      eventHandler.trigger 'connect', err, {}

  # Broadcasts a message to every socket,
  # except author
  broadcast: (message, echo = false) ->
    console.error LOG, "Error: Connect first" if not redisClient

    # session users
    sockets = Database.sessionUsers.getSockets message.session
    states = Database.sessionUsers.getConnStates message.session

    # Avoid echo, exclude author connection
    excludeSockets = []
    if not echo
      excludeSockets = Database.userSockets.get message.author

    console.log LOG, message.type, message.id
    message.timestamp = Date.now()

    # Add to Redis
    redisClient.rpush ("session_#{message.session}"), JSON.stringify message

    # Send it to the peers
    for socket in sockets
      if socket not in excludeSockets
        socket.sendUTF JSON.stringify message

    eventHandler.trigger 'broadcast', null,
      undelivered: states.offline
      message: message

  # Broadcasts a notice to every socket
  notice: (message, sockets) ->
    console.error LOG, "Error: Connect first" if not redisClient

    console.log LOG, message.type, message.id
    message.timestamp = Date.now()

    # Send it to the peers
    for socket in sockets
      socket.sendUTF JSON.stringify message

    eventHandler.trigger 'notice', null, {}

  # Kick one or more users from session, userIds are optional
  kick: (sessionId, userIds) ->
    userIds = userIds or Database.sessionUsers.get(sessionId)

    if 'object' isnt typeof userIds
      userIds = [userIds]

    ts = Date.now()
    for userId in userIds
      # Bump signature validity so users can't re-join
      PapersPlease.checkSignatureValidity userId, 'sessions', ts
      # Send kick notification
      for socket in Database.userSockets userId
        socket.sendUTF JSON.stringify
          id: null
          type: 'kick'
          status: 1000
          data: session: sessionId

  # Closes a session
  destroy: (sessionId) ->
    console.error LOG, "Error: Connect first" if not redisClient

    userIds = Database.sessionUsers.get(sessionId)
    # Kick users
    actions.kick sessionId, userIds
    # Revoke access
    Database.userSessions.remove userIds, sessionId
    # Destroy session
    Database.sessionUsers.destroy sessionId
    # Destroyed
    eventHandler.trigger 'destroy', null, {}

  # Load user's sessions messages
  loadSessions: (user, messageId) ->
    console.error LOG, "Error: Connect first" if not redisClient

    multi = redisClient.multi()
    for userSession in Database.userSessions.get user.id

      if not Database.sessionUsers.has userSession, user.id
        console.error LOG, "loadSessions: Inconsistent DB for #{user.id}!",
          "sessionUsers:",
          Database.sessionUsers.get(userSession),
          "userSessions:",
          Database.userSessions.get(user.id)
      else
        multi.lrange ("session_#{userSession}"), 0, -1

    multi.exec (err, results) ->
      messagesHistory = []
      if not err
        for result in results
          if result.length
            for messageResult in result
              try
                messagesHistory.push JSON.parse messageResult
              catch ex
                console.error LOG, 'Error parse:', messageResult

        for conn in Database.userSockets.get user.id
          conn.sendUTF utils.mkResponse 2000, messageId, 'joined', null,
            messages: messagesHistory
      else
        console.error LOG, "Error loading user sessions", err

      eventHandler.trigger 'loadSessions', err,
        user: user, history: messagesHistory

actions.on = eventHandler.on
actions.off = eventHandler.off
