#!/usr/bin/env node

WebSocketServer = require('websocket').server
amqp = require 'amqplib'
all = (require 'when').all
http = require 'http'
utils = require './lib/utils'
papersPlease = require './lib/papersPlease'
config = require './lib/config'

# list of currently connected clients
db = require './lib/localData'

messageManager = require './lib/messageManager'
chat = require './lib/chatActions'

###
  AMQP --------------------------------------------------------------
###

exchange = 'amq.topic'
keys = ['chat.attachment', 'session.close']

connectAMQP = (n = 0) ->
  amqp.connect(config.amqp.url).then (conn) ->
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
    console.error err
    # 10 retries
    if n < 9
      console.info 'Retrying'
      process.nextTick ->
        connectAMQP n++
    else
      console.error 'No more retries'

connectAMQP 0

###
  AMQP HANDLER ------------------------------------------------------
###

amqpHandler = (msg) ->
  key = msg.fields.routingKey
  try
    data = JSON.parse msg.content.toString()
  catch e
    console.error e

  # Attachment received
  if key is 'chat.attachment'
    for message in data
      chat.broadcast message

  # Close received
  if key is 'session.close'
    console.log new Date(), 'session.close', data.id
    chat.destroy data.id

###
  WEBSOCKETS --------------------------------------------------------
###

server = http.createServer (request, response) ->
  console.log new Date(), 'Received request for', request.url
  response.writeHead 404
  response.end()

server.listen config.ws.port, ->
  console.log new Date(), 'Server is listening on port', config.ws.port

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
  if not papersPlease.request request
    console.warn new Date(), 'Connection from origin', request.origin, 'rejected'
    return request.reject()

  connection = request.accept null, request.origin
  index = db.addClient connection

  # User data initialization
  user =
    role: 'client'
    id: null
    name: null
    sessions: {}
    auth: false
    connection: connection

  console.log new Date(),'Connection accepted.'

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

        # Test if handshake is done
        if not user.id and message.type isnt 'handshake' and
        message.type isnt 'ping'
          console.warn message.id, 'Before handshake', message.type,
            message.data
          return connection.sendUTF utils.mkResponse 4010

        # check if messageString is valid
        # check required fields
        if not papersPlease.required message, user.id
          console.warn message.id, 'Missing fields', message.type, message.data
          return connection.sendUTF utils.mkResponse 4030, (message.id + '')

        # set author
        message.author = user.id
        # set session
        session = message.session

        # Send to messageManager
        console.log new Date(), message.type, message.id
        messageManager message, user

    else
      console.warn new Date(), 'Message type:', messageString.type

  connection.on 'close', (reasonCode, description) ->
    if user.id
      console.log new Date(), 'Peer', connection.remoteAddress, 'disconnected.'
      # remove connection
      db.removeClient index
      # remove user socket from list
      db.removeUserSocket user.id, connection