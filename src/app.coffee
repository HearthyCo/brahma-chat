#!/usr/bin/env node

require('better-console-log')()

WebSocketServer = require('websocket').server
http = require 'http'
utils = require './lib/utils'

PapersPlease = require './lib/papersPlease'
Config = require './lib/config'
Database = require './lib/database'

###
  SERVICES ----------------------------------------------------------
###

amqp = require './lib/amqp'
amqp.connect Config.amqp

Chat = require './lib/chatActions'
Chat.connect Config

MessageManager = require './lib/messageManager'

###
  EVENTS ------------------------------------------------------------
###

# CHAT -------------------
Chat.on 'broadcast', (err, data) ->
  if data and data.undelivered
    amqp.publish 'chat.activity', data

Chat.on '*', (evt) ->
  console.log "Chat event [" + evt + "] triggered"

# MESSAGEMANAGER ---------
MessageManager.on ['attachment', 'message'], 'broadcast', (err, data) ->
  Chat.broadcast data.message if not err

MessageManager.on ['handshake', 'session'], 'loadSession', (err, data) ->
  Chat.loadSessions data.user, data.message.id if not err

MessageManager.on '*', (evt) ->
  console.log "MessageManager event [" + evt + "] triggered"

# AMQP ---------------------
amqp = require './lib/amqp'
amqp.connect Config.amqp

# Connected and ready to publish
amqp.on 'appendReady', 'requestSessions', ->
  amqp.publish 'request.sessions.users', {}

# Attachment received
amqp.on 'chat.attachment', 'broadcast', (err, data) ->
  for message in data
    Chat.broadcast message

# Close received
amqp.on 'session.close', 'destroy', (err, data) ->
  console.log 'session.close', data.id
  Chat.destroy data.id

amqp.on 'session.users', 'users', (err, data) ->
  console.log 'session.users', data.id, data.userIds
  Database.sessionUsers.set data.id, data.userIds

amqp.on 'sessions.users', 'users', (err, data) ->
  console.log 'sessions.users', data
  _old = Database.sessionUsers.getIds()
  _new = Object.keys data.sessions
  # TODO: Save user sessions in each user
  # save new
  for sessionId, userIds of data.sessions
    Database.sessionUsers.set sessionId, userIds
  # remove old
  for sessionId of _old
    if sessionId not in _new
      Database.sessionUsers.destroy sessionId

amqp.on 'sessions.pools', 'broadcast', (err, data) ->
  console.log 'sessions.pools', data.servicetypes
  Chat.notice
    id: null
    type: 'update'
    status: 1000
    data: servicetypes: data.servicetypes,
    Database.userSockets.getProfessionals()

amqp.on '*', (evt) ->
  console.log "amqp event [" + evt + "] triggered"

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
  index = Database.connections.add connection

  # User data initialization
  user =
    role: 'client'
    id: null
    sessions: {}

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
        MessageManager message, user, connection

    else
      console.warn 'Message type:', messageString.type

  connection.on 'close', (reasonCode, description) ->
    if user.id
      console.log 'Peer', connection.remoteAddress,
        'disconnected.', reasonCode, description
      # remove connection
      Database.connections.remove index
      # remove user socket from list
      Database.userSockets.remove user.id, connection

      if not Database.userSockets.get(user.id).length
        Database.users.remove user.id

      Database.sessionUsers.remove user.sessions, user.id
