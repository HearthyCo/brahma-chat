#!/usr/bin/env node

require('better-console-log')()

WebSocketServer = require('websocket').server
http = require 'http'
utils = require './lib/utils'

PapersPlease = require './lib/papersPlease'
Config = require './lib/config'
Database = require './lib/database'

LOG = "App  >"

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
  console.log LOG, "Chat event [#{evt}] triggered"

# MESSAGEMANAGER ---------
MessageManager.on ['attachment', 'message'], 'broadcast', (err, data) ->
  Chat.broadcast data.message if not err

MessageManager.on ['handshake', 'session'], 'loadSession', (err, data) ->
  Chat.loadSessions data.user, data.message.id if not err

MessageManager.on '*', (evt) ->
  console.log LOG, "MessageManager event [#{evt}] triggered"

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
  console.log LOG, 'session.close', data.id
  Chat.destroy data.id

amqp.on 'session.users', 'users', (err, data) ->
  console.log LOG, 'session.users', data.id, data.userIds
  Database.sessionUsers.set data.id, data.userIds
  # TODO: update users.sessions

amqp.on 'sessions.users', 'users', (err, data) ->
  console.log LOG, 'sessions.users', data
  _old = Database.sessionUsers.getIds()
  _new = Object.keys data.sessions

  # save new
  Database.sessionUsers.load data.sessions
  Database.userSessions.loadFromSessions data.sessions

  # kick from old
  for sessionId of _old
    if sessionId not in _new
      Chat.kick sessionId

amqp.on 'sessions.pools', 'broadcast', (err, data) ->
  console.log LOG, 'sessions.pools', data.serviceTypes
  Chat.notice
    id: null
    type: 'update'
    status: 1000
    data: servicetypes: data.servicetypes,
    Database.userSockets.getProfessionals()

amqp.on '*', (evt) ->
  console.log LOG, "amqp event [#{evt}] triggered"

###
  WEBSOCKETS --------------------------------------------------------
###

server = http.createServer (request, response) ->
  console.log LOG, 'Received request for', request.url
  response.writeHead 404
  response.end()

server.listen Config.ws.port, ->
  console.log LOG, 'Server is listening on port', Config.ws.port

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
    console.warn LOG, 'Connection from origin',
      request.origin, 'rejected'
    return request.reject()

  connection = request.accept null, request.origin
  index = Database.connections.add connection

  # User data initialization
  user =
    role: 'client'
    id: null
    sessions: {}

  console.log LOG, 'Connection accepted.'

  connection.on 'message', (messageString) ->
    if messageString.type is 'utf8'
      # JSON messageString
      try
        messages = JSON.parse messageString.utf8Data
      catch ex
        console.warn LOG, "JSON.parse:", ex
        return connection.sendUTF utils.mkResponse 4000

      if Object.prototype.toString.call(messages) isnt '[object Array]'
        messages = [messages]

      for message in messages

        # Test if handshake is done
        if not user.id and message.type isnt 'handshake' and
        message.type isnt 'ping'
          console.warn LOG, message.id, 'Before handshake', message.type,
            message.data
          return connection.sendUTF utils.mkResponse 4010

        # check if messageString is valid
        # check required fields
        if not PapersPlease.required message, user.id
          console.warn LOG, message.id, 'Missing fields',
            message.type, message.data
          return connection.sendUTF utils.mkResponse 4030, "#{message.id}"

        # set author
        message.author = user.id

        # Send to MessageManager
        console.log LOG, message.type, message.id
        MessageManager message, user, connection

    else
      console.warn LOG, 'Message type:', messageString.type

  connection.on 'close', (reasonCode, description) ->
    if user.id
      console.log LOG, 'Peer', connection.remoteAddress,
        'disconnected.', reasonCode, description

      # remove connection
      Database.connections.remove index
      # remove user socket from list
      Database.userSockets.remove user.id, connection

      # Remove user if offline
      if not Database.userSockets.get(user.id).length
        Database.users.remove user.id
