#!/usr/bin/env node

WebSocketServer = require('websocket').server
redis = require 'redis'
amqp = require 'amqp'
http = require 'http'
wsUtils = require './lib/utils'
papersPlease = require './lib/papersPlease'
sendStatus = require './lib/sendStatus'

config = require './lib/config'

###
  REDIS -------------------------------------------------------------
###
redisClient = redis.createClient()
# if you'd like to select database 3, instead of 0 (default), call
# redisClient.select(3, function() { /* ... */ });
redisClient.on 'error', (err) ->
  console.error 'Redis error ' + err
  return
redisClient.on 'connect', ->
  console.error 'Redis connected'
  return

###
  AMQP --------------------------------------------------------------
###
amqpClient = amqp.createConnection()

# Wait for connection to become established.
amqpClient.on 'ready', ->
  # Use the default 'amq.topic' exchange
  connection.queue 'join', (q) ->
    console.error 'AMQP queue: join'
    # Catch all messages
    q.bind '#'

    q.subscribe (message) ->
      console.log 'AMQP message:' + message

###
  CONFIG ------------------------------------------------------------
###
config =
  port: 1337
  colors:
    client: [ 'magenta', 'purple', 'plum', 'orange' ]
    professional: [ 'red', 'green', 'blue' ]

###
  INTERNAL DB -------------------------------------------------------
###

# list of currently connected clients (users)
clients = []
users = {}
# list of currently connected sessions
sessions = {}

###
  WEBSOCKETS --------------------------------------------------------
###

server = http.createServer (request, response) ->
  console.log (new Date()) + ' Received request for ' + request.url
  response.writeHead 404
  response.end()

server.listen config.port, ->
  console.log (new Date()) + ' Server is listening on port ' + config.port

wsServer = new WebSocketServer(
  httpServer: server,
  # You should not use autoAcceptConnections for production
  # applications, as it defeats all standard cross-origin protection
  # facilities built into the protocol and the browser.  You should
  # *always* verify the connection's origin and decide whether or not
  # to accept it.
  autoAcceptConnections: false)

wsServer.on 'request', (request) ->
  if !papersPlease.request request
    request.reject()
    console.log new Date(), 'Connection from origin', request.origin, 'rejected'
    return

  connection = request.accept null, request.origin
  index = clients.push(connection) - 1

  # User data initialization
  user =
    role: 'client'
    id: null
    name: null
    sessions: {}
    auth: false

  console.log new Date(),'Connection accepted.'
  console.log connection.on

  connection.on 'message', (messageString) ->
    if messageString.type == 'utf8'
      # JSON messageString
      try
        messages = JSON.parse messageString.utf8Data
      catch e
        return connection.sendUTF sendStatus 4000

      if Object.prototype.toString.call(messages) isnt '[object Array]'
        messages = [messages]

      for message in messages
        console.log 'MESSAGE', message
        console.log 'EVAL', not user.id, message.type isnt 'handshake', message.type isnt 'ping'
        if not user.id and message.type isnt 'handshake' and message.type isnt 'ping'
          return connection.sendUTF sendStatus 4010

        # messageString id
        id = message.id + ''

        # check if messageString is valid
        if not papersPlease.message message
          return connection.sendUTF sendStatus 4030, id

        message.author = user.id
        # milliseconds
        message.timestamp = Date.now()

        # do something with it
        session = message.session
        switch message.type
          when 'ping'
            connection.sendUTF JSON.stringify id: id, type: 'pong'
            console.log new Date(), 'Ping? PONG!'

          when 'handshake'
            if not papersPlease.handshake message
              return connection.sendUTF sendStatus 4010, id

            user.id = message.data.userId
            user.sessions = message.data.sessions || []

            userSessions = user.sessions
            for userSession in userSessions
              if not sessions[userSession]
                sessions[userSession] = []
              else
                name = 'session_' + userSession
                redisClient.llen name, (err, size) ->
                  if not err
                    redisClient.lrange (name), 0, size, (err, reply) ->
                      connection.sendUTF '[' + reply + ']'

              if not (connection in sessions[userSession])
                sessions[userSession].push connection

            connection.sendUTF JSON.stringify sendStatus 2000, id

          # when 'history'
          #   if session?
          #     name = 'session_' + session
          #     size = redisClient.llen name
          #     redisClient.lrange (name), 0, size, (err, reply) ->
          #       msg = if err then 'REDIS ERROR: ' + err else 'REDIS: ' + reply
          #       console.log msg

          when 'message'
            console.log 'SESSION', session
            console.log 'SESSIONS', sessions
            if session?
              redisClient.rpush ('session_' + session), JSON.stringify message

              for listener in sessions[session]
                if listener isnt connection
                  listener.sendUTF JSON.stringify [message]

              console.log new Date(), 'Received:', JSON.stringify message

          when 'attachment'
            if session
              redisClient.rpush ('session_' + session), JSON.stringify message

              for listener in sessions[session]
                listener.sendUTF JSON.stringify message
              console.log new Date(), 'Received Attach:', messageString.utf8Data

    # else if message.type == 'binary'
    #   console.log 'Received Binary Message of', message.binaryData.length, 'bytes'
    #   console.log 'Binary rejected'
    #   connection.sendBytes message.binaryData
    else
      console.warn (new Date()) + ' Message type ' + messageString.type

  connection.on 'close', (reasonCode, description) ->
    if user.id
      console.log new Date(), 'Peer', connection.remoteAddress, 'disconnected.'
      # remove connection
      clients.splice index, 1
      # remove user data
      delete users[user.id]
