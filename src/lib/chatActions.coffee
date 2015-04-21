config = require './config'
redis = require 'redis'
db = require './localData'

###
  REDIS -------------------------------------------------------------
###

redisClient = redis.createClient(config.redis.port, config.redis.host, {})
redisClient.on 'error', (err) ->
  console.error 'Redis error', err
  return
redisClient.on 'connect', ->
  console.info 'Redis connected'
  return

actions =
  # Broadcasts a message to every socket,
  # except author
  broadcast: (message, sockets, excludeSockets) ->
    # sessions
    sockets = sockets or db.getSessionSockets message.session
    # Avoid echo, exclude author connection
    excludeSockets = excludeSockets or db.getUserSockets message.author

    console.log new Date(), message.type, message.id
    message.timestamp = Date.now()

    # Add to Redis
    redisClient.rpush ('session_' + message.session), JSON.stringify message

    # Send it to the peers
    for listener in connections
      if listener not in excludeSockets
        listener.sendUTF JSON.stringify message

  # Closes a session
  destroy: (sessionId) ->
    ts = Date.now()
    for listener in db.getSessionSockets sessionId
      # Bump signature validity so users can't re-join
      papersPlease.checkSignatureValidity listener.user.id, 'sessions', ts
      # Send kick notification
      listener.sendUTF JSON.stringify
        id: null
        type: 'kick'
        status: 1000
        data: session: data.id
    # Destroy session
    db.removeSessionSockets sessionId

  # Load user's sessions messages
  loadSessions: (user, callback) ->
    multi = redisClient.multi()
    for userSession in user.sessions
      if db.getSessionSockets userSession
        multi.lrange ('session_' + userSession), 0, -1

      if not db.sessionHasSocket userSession, connection
        db.addSessionSocket userSession, connection

    multi.exec (err, results) ->
      messagesHistory = []
      if not err
        for result in results
          if result.length
            for messageResult in result
              try
                messagesHistory.push JSON.parse messageResult
              catch e
                console.log new Date(), 'Error parse:', messageResult

      callback err, messagesHistory

module.exports = actions