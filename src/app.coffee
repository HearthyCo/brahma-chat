#!/usr/bin/env node

require('better-console-log')()

WebSocketServer = require('websocket').server
amqp = require 'amqplib'
all = (require 'when').all
http = require 'http'
utils = require './lib/utils'

PapersPlease = require './lib/PapersPlease'
Config = require './lib/Config'
Database = require './lib/Database'
MessageManager = require './lib/MessageManager'
Chat = require './lib/ChatActions'

Chat.connect Config

###
  AMQP HANDLER ------------------------------------------------------
###

amqpHandler = (msg) ->
  key = msg.fields.routingKey
  try
    data = JSON.parse msg.content.toString()
  catch ex
    console.error "JSON.parse:", ex

  # Attachment received
  if key is 'Chat.attachment'
    for message in data
      Chat.broadcast message

  # Close received
  if key is 'session.close'
    console.log 'session.close', data.id
    Chat.destroy data.id

###
  AMQP --------------------------------------------------------------
###

exchange = 'amq.topic'
keys = ['Chat.attachment', 'session.close']

connectAMQP = (n = 0) ->
  amqp.connect(Config.amqp.url).then (conn) ->
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
        console.info 'AMQP listening'
  .then null, (err) ->
    # 10 retries
    if n < 9
      console.warn "AMQP. Retry #{n+1} after:", err
      n = n + 1
      process.nextTick ->
        connectAMQP n
    else
      console.error 'AMQP. No more retries after:', err

connectAMQP 0

###
  WEBSOCKETS --------------------------------------------------------
###

server = http.createServer (request, response) ->
  console.log 'Received request for', request.url
  response.writeHead 404
  response.end()

server.listen Config.ws.port, ->
  console.log 'Server is listening on port', Config.ws.port

wsServer = new WebSocketServer(
  httpServer: server,
  # You should not use autoAcceptConnections for production
  # applications, as it defeats all standard cross-origin protection
  # facilities built into the protocol and the browser.  You should
  # *always* verify the connection's origin and decide whether or not
  # to accept it.
  autoAcceptConnections: false
)

wsServer.on 'request', (request) ->
  if not PapersPlease.request request
    console.warn 'Connection from origin',
      request.origin, 'rejected'
    return request.reject()

  connection = request.accept null, request.origin
  index = Database.client.add connection

  # User data initialization
  user =
    role: 'client'
    id: null
    name: null
    sessions: {}
    auth: false
    connection: connection

  console.log 'Connection accepted.'

  connection.on 'message', (messageString) ->
    if messageString.type == 'utf8'
      # JSON messageString
      try
        messages = JSON.parse messageString.utf8Data
      catch ex
        console.warn "JSON.parse:", ex
        return connection.sendUTF utils.mkResponse 4000

      if Object.prototype.toString.call(messages) isnt '[object Array]'
        messages = [messages]

      for message in messages

        # Test if handshake is done
        if not user.id and message.type isnt 'handshake' and
        message.type isnt 'ping'
          console.warn message.id, 'Before handshake', message.type,
            message.data
          return connection.sendUTF utils.mkResponse 4010

        # check if messageString is valid
        # check required fields
        if not PapersPlease.required message, user.id
          console.warn message.id, 'Missing fields', message.type, message.data
          return connection.sendUTF utils.mkResponse 4030, (message.id + '')

        # set author
        message.author = user.id

        # Send to MessageManager
        console.log message.type, message.id
        MessageManager message, user

    else
      console.warn 'Message type:', messageString.type

  connection.on 'close', (reasonCode, description) ->
    if user.id
      console.log 'Peer', connection.remoteAddress,
        'disconnected.', reasonCode, description
      # remove connection
      Database.client.remove index
      # remove user socket from list
      Database.userSockets.remove user.id, connection