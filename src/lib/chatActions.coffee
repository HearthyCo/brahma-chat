Config = require './Config'
redis = require 'redis'
Database = require './Database'
PapersPlease = require './PapersPlease'

###
  REDIS -------------------------------------------------------------
###

redisClient = null
redisConnect = (cfg, callback) ->
  callback = callback or (err) ->
    console.error 'Redis error', err if err

  ###coffeelint-variable-scope-ignore###
  redisClient = redis.createClient cfg.port, cfg.host, {}
  redisClient.on 'error', callback
  redisClient.on 'connect', callback

module.exports = actions =
  connect: (_Config = Config) ->
    # Open Redis connection
    redisConnect _Config.redis, (err) ->
      if err
        console.error 'Redis error', err
      else
        console.info 'Redis connected'

      _trigger 'connect', err, {}

  # Broadcasts a message to every socket,
  # except author
  broadcast: (message, sockets, excludeSockets) ->
    console.error "Error: Connect first" if not redisClient

    # sessions
    sockets = sockets or Database.sessionSockets.get message.session
    # Avoid echo, exclude author connection
    excludeSockets = excludeSockets or Database.userSockets.get message.author

    console.log message.type, message.id
    message.timestamp = Date.now()

    # Add to Redis
    redisClient.rpush ('session_' + message.session), JSON.stringify message

    # Send it to the peers
    for listener in sockets
      if listener not in excludeSockets
        listener.sendUTF JSON.stringify message

    _trigger 'broadcast', null, {}

  # Closes a session
  destroy: (sessionId) ->
    console.error "Error: Connect first" if not redisClient

    ts = Date.now()
    for listener in Database.sessionSockets.get sessionId
      # Bump signature validity so users can't re-join
      PapersPlease.checkSignatureValidity listener.user.id, 'sessions', ts
      # Send kick notification
      listener.sendUTF JSON.stringify
        id: null
        type: 'kick'
        status: 1000
        data: session: data.id
    # Destroy session
    Database.sessionSockets.destroy sessionId
    _trigger 'destroy', err, {}

  # Load user's sessions messages
  loadSessions: (user) ->
    console.error "Error: Connect first" if not redisClient

    multi = redisClient.multi()
    for userSession in user.sessions
      if Database.sessionSockets.get userSession
        multi.lrange ('session_' + userSession), 0, -1

      if not Database.sessionSockets.has userSession, user.connection
        Database.sessionSockets.add userSession, user.connection

    multi.exec (err, results) ->
      messagesHistory = []
      if not err
        for result in results
          if result.length
            for messageResult in result
              try
                messagesHistory.push JSON.parse messageResult
              catch e
                console.log 'Error parse:', messageResult

        data.user.connection.sendUTF utils.mkResponse 2000, id, 'joined', null,
          messages: messagesHistory
      else
        console.error "Error loading user sessions", err

      _trigger 'loadSessions', err,
        user: user, history: messagesHistory


# Events
_on = {}
_trigger = (ev, err, payload) ->
  _on[ev](err, payload) if _on[ev]

actions.on = (ev, callback) ->
  if 'object' is typeof ev
    ev.forEach (e) ->
      _on[e] = callback if 'function' is typeof callback
    return true
  else
    _on[ev] = callback if 'function' is typeof callback
  return _on[ev]

actions.off = (ev) ->
  if 'object' is typeof ev
    ev.forEach (e) ->
      _on[e] = undefined
      delete _on[e]
  else
    _on[ev] = undefined
    delete _on[ev]
