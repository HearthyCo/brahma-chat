redis = require 'redis'
Config = require './config'
Database = require './database'
PapersPlease = require './papersPlease'
utils = require './utils'
_ = require 'underscore'

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
  # except the specific ones passed on except
  broadcast: (message, except) ->
    console.error LOG, "Error: Connect first" if not redisClient

    # session users
    sockets = Database.sessionUsers.getSockets message.session
    states = Database.sessionUsers.getConnStates message.session

    # Exclude this sockets, used by echo
    excludeSockets = if except instanceof Array then except else [except]

    message.timestamp = Date.now()
    console.log LOG, "Broadcast #{message.type} #{message.id}", states

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

    message.timestamp = Date.now()
    console.log LOG, "Notice #{message.type} #{message.id}"

    # Send it to the peers
    for socket in sockets
      socket.sendUTF JSON.stringify message

    eventHandler.trigger 'notice', null, {}

  # Kick one or more users from session, userIds are optional
  kick: (sessionId, userIds) ->
    userIds = userIds or Database.sessionUsers.get(sessionId)

    if 'object' isnt typeof userIds
      userIds = [userIds]

    console.log LOG, "Kick ##{sessionId} -> @", userIds

    ts = Date.now()
    for userId in userIds
      # Bump signature validity so users can't re-join
      PapersPlease.checkSignatureValidity userId, 'sessions', ts
      # Send kick notification
      for socket in Database.userSockets.get userId
        socket.sendUTF JSON.stringify
          id: null
          type: 'kick'
          status: 1000
          data: session: sessionId

    eventHandler.trigger 'kick', null, sessionId: sessionId, userIds: userIds

  # Closes a session
  destroy: (sessionId) ->
    console.error LOG, "Error: Connect first" if not redisClient
    console.log LOG, "Destroy ##{sessionId}"

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
  loadSession: (userId, sessionId, messageId) ->
    console.error LOG, "Error: Connect first" if not redisClient
    console.log LOG, "@#{userId} ##{sessionId} Loading session"

    redisClient.lrange ["session_#{sessionId}", 0, -1], (err, results) ->
      messagesHistory = []
      if not err
        for messageResult in results
          try
            messagesHistory.push JSON.parse messageResult
          catch ex
            console.error LOG, "@#{userId} Error parse:",
              messageResult

        for conn in Database.userSockets.get userId
          conn.sendUTF utils.mkResponse 2000, messageId, 'joined', null,
            message: messagesHistory
      else
        console.error LOG, "@#{userId} ##{sessionId}",
          "Error loading user sessions", err

      eventHandler.trigger 'loadSession', err,
        userId: userId, history: messagesHistory

  # Load user's sessions messages
  loadSessions: (user, messageId) ->
    console.error LOG, "Error: Connect first" if not redisClient
    console.log LOG, "@#{user?.id or '?'} Loading sessions"

    multi = redisClient.multi()
    queries = []
    for userSession in Database.userSessions.get user.id

      if not Database.sessionUsers.has userSession, user.id
        console.error LOG, "@#{user?.id or '?'} loadSessions inconsistent DB!",
          "sessionUsers:",
          Database.sessionUsers.get(userSession),
          "userSessions:",
          Database.userSessions.get(user.id)
      else
        multi.lrange ("session_#{userSession}"), 0, -1
        multi.get ("userStatus_#{user.id}_#{userSession}")
        queries.push userSession

    multi.exec (err, results) ->
      messagesHistory = []
      statusList = []
      if not err
        logs  = (v for v in results by 2)
        status = (v for v in results[1..] by 2)
        for result in logs
          if result.length
            for messageResult in result
              try
                messagesHistory.push JSON.parse messageResult
              catch ex
                console.error LOG, "@#{user?.id or '?'} Error parse:",
                  messageResult
        for result, i in status
          if result
            sessionId = queries[i]
            entity = _.extend {}, JSON.parse(result),
              id: sessionId
              chatId: sessionId
            statusList.push entity
        for conn in Database.userSockets.get user.id
          conn.sendUTF utils.mkResponse 2000, messageId, 'joined', null,
            message: messagesHistory
            chatStatus: statusList
      else
        console.error LOG, "@#{user?.id or '?'} Error loading user sessions",
          err

      eventHandler.trigger 'loadSessions', err,
        user: user, history: messagesHistory

  # Send online professionals count update
  updateProfessionalCount: (conn) ->
    actions.updateProfessionalList(conn, false)

  # Send online professionals list update
  updateProfessionalList: (conn, includeList = false) ->
    sockets = if conn then [conn] else Database.userSockets.getClients()
    professionals = Database.users.getProfessionals()
    miscEntry =
      id: 'professionalsOnline'
      count: professionals.length
    miscEntry.list = professionals if includeList
    msg =
      id: null
      type: 'update'
      status: 1000
      data: misc: [miscEntry]
    actions.notice msg, sockets

  # Update user-session status
  updateUserSessionStatus: (userId, sessionId, status) ->
    # Update on Redis
    redisClient.set ("userStatus_#{userId}_#{sessionId}"), JSON.stringify status

    # Send it to all sockets of this user
    entity = _.extend {}, status,
      id: sessionId
      chatId: sessionId
    message =
      id: null
      type: 'status'
      status: 2000
      data:
        chatStatus: [entity]
    sockets = Database.userSockets.get userId
    for socket in sockets
      socket.sendUTF JSON.stringify message

actions.on = eventHandler.on
actions.off = eventHandler.off
