#!/usr/bin/env node

WebSocketServer = require('websocket').server
http = require 'http'
wsUtils = require './lib/utils'
papersPlease = require './lib/papersPlease'
sendStatus = require './lib/sendStatus'

config =
  port: 1337
  colors:
    client: [ 'magenta', 'purple', 'plum', 'orange' ]
    professional: [ 'red', 'green', 'blue' ]

# list of currently connected clients (users)
clients = []
users = {}
# list of currently connected sessions
sessions = {}

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
    console.log (new Date()) + ' Connection from origin ' + request.origin + ' rejected.'
    return

  connection = request.accept null, request.origin
  index = clients.push(connection) - 1

  # User data initialization
  user = {
    role: 'client'
    id: null
    name: null
    sessions: {}
    auth: false
  }

  connection.sendUTF JSON.stringify
    type: 'message'
    data: message: "Hello =)"

  console.log (new Date()) + ' Connection accepted.'

  connection.on 'message', (message) ->
    if message.type == 'utf8'

      # JSON message
      try
        objectData = JSON.parse message.utf8Data
      catch e
        return connection.sendUTF sendStatus 4000

      # first message must be json with information
      if not user.name and objectData.type isnt "handshake" and objectData.type isnt "ping"
        return connection.sendUTF sendStatus 4010

      # check if message is valid
      if !papersPlease.message objectData
        return connection.sendUTF sendStatus 4030

      # do something with it
      switch objectData.type
        when 'ping'
          connection.sendUTF JSON.stringify { type: "pong" }
          console.log (new Date()) + ' PING? PONG'
        when 'handshake'
          user = objectData.data.user
          connection.sendUTF JSON.stringify sendStatus 2000

        when 'message'
          connection.sendUTF message.utf8Data
          console.log (new Date()) + ' Received Message: ' + message.utf8Data

        when 'attachment'
          connection.sendUTF message.utf8Data
          console.log (new Date()) + ' Received Attachment: ' + message.utf8Data

    # else if message.type == 'binary'
    #   console.log 'Received Binary Message of ' + message.binaryData.length + ' bytes'
    #   console.log 'Binary rejected'
    #   connection.sendBytes message.binaryData
    else
      console.warn (new Date()) + ' Message type ' + message.type

  connection.on 'close', (reasonCode, description) ->
    if user.name
      console.log new Date + ' Peer ' + connection.remoteAddress + ' disconnected.'
      # remove connection
      clients.splice index, 1
      # remove user data
      delete users[user.id]
