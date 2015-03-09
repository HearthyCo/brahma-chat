#!/usr/bin/env node

WebSocketServer = require('websocket').server
redis = require 'redis'
amqp = require 'amqplib'
all = (require 'when').all
http = require 'http'
utils = require './lib/utils'
papersPlease = require './lib/papersPlease'

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
exchange = 'amq.topic'
keys = ['#']

amqp.connect().then (conn) ->
  conn.createChannel().then (ch) ->
    ok = ch.assertExchange exchange, 'topic', durable: true
    ok = ok.then ->
      ch.assertQueue '', exclusive: true
    ok = ok.then (qok) ->
      queue = qok.queue
      t = all keys.map (rk) -> ch.bindQueue queue, exchange, rk
      t.then -> queue
    ok = ok.then (queue) ->
      ch.consume queue, amqpHandler
    return ok.then ->
      console.error 'AMQP listening'
.then null, console.error

amqpHandler = (msg) ->
  key = msg.fields.routingKey
  try
    data = JSON.parse msg.content.toString()
  catch e
    console.error e
  console.log 'AMQP Received:', key, data

  if key is 'chat.attachment'
    for message in data
      authorConnection = users[message.author]
      session = sessions[message.session]
      message.timestamp = Date.now()
      # Add to Redis
      redisClient.rpush ('session_' + session), JSON.stringify message
      # Send it to the peers
      for listener in session
        if listener isnt authorConnection
          listener.sendUTF JSON.stringify [message]

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
  if not papersPlease.request request
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
        return connection.sendUTF utils.mkResponse 4000

      if Object.prototype.toString.call(messages) isnt '[object Array]'
        messages = [messages]

      for message in messages
        # console.log 'MSG', message
        if not user.id and message.type isnt 'handshake' and
        message.type isnt 'ping'
          return connection.sendUTF utils.mkResponse 4010

        # messageString id
        id = message.id + ''

        # check if messageString is valid
        # check required fields
        if not papersPlease.required message, user.id
          return connection.sendUTF utils.mkResponse 4030, id

        message.author = user.id
        message.timestamp = Date.now()

        # set session
        session = message.session

        switch message.type
          when 'ping'
            connection.sendUTF utils.mkResponse 2000, id, 'pong'

          when 'session'
            if not papersPlease.session message
              return connection.sendUTF utils.mkResponse 4010, id
            user.sessions = message.data.sessions

          when 'handshake'
            if not papersPlease.handshake message
              return connection.sendUTF utils.mkResponse 4010, id

            # Set user
            user.id = message.data.userId
            user.sessions = message.data.sessions || []
            users[user.id] = connection

            multi = redisClient.multi()

            userSessions = user.sessions
            for userSession in userSessions
              if not sessions[userSession]
                sessions[userSession] = []
              else
                multi.lrange ('session_' + userSession), 0, -1

              if not (connection in sessions[userSession])
                sessions[userSession].push connection

            multi.exec (err, results) ->
              messagesHistory = []
              if not err and results.length
                for result in results
                  if result.length > 0
                    for messageResult in result
                      try
                        messagesHistory.push JSON.parse messageResult
                      catch e
                        console.log new Date(), 'Error parse:', messageResult

              connection.sendUTF utils.mkResponse 2000, id, 'granted', null,
                messages: messagesHistory

          when 'message'
            if not papersPlease.message message, user.sessions
              return connection.sendUTF utils.mkResponse 4010, id

            if session?
              redisClient.rpush ('session_' + session), JSON.stringify message

              for listener in sessions[session]
                if listener isnt connection
                  listener.sendUTF JSON.stringify [message]

          when 'attachment'
            if not papersPlease.message message, user.sessions
              return connection.sendUTF utils.mkResponse 4010, id

            if session
              redisClient.rpush ('session_' + session), JSON.stringify message

              for listener in sessions[session]
                listener.sendUTF JSON.stringify message

        console.log new Date(), message.type, message.id

    # else if message.type == 'binary'
    #   console.log 'Received Binary Message of', message.binaryData.length, 'bytes'
    #   console.log 'Binary rejected'
    #   connection.sendBytes message.binaryData
    else
      console.warn new Date(), 'Message type:', messageString.type

  connection.on 'close', (reasonCode, description) ->
    if user.id
      console.log new Date(), 'Peer', connection.remoteAddress, 'disconnected.'
      # remove connection
      clients.splice index, 1
      # remove user data
      delete users[user.id]
