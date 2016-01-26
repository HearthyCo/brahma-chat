#!/usr/bin/env node

require('better-console-log')()

process.on "uncaughtException", (err) ->
  console.error "uncaughtException", (err.stack or err)

WebSocketServer = require('websocket').server
http = require 'http'
utils = require './lib/utils'

Config = require './lib/config'
Connect = require './lib/connect'
PapersPlease = require './lib/papersPlease'
Database = require './lib/database'
Tracking = require './lib/tracking'

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

Chat.on ['unreadDisconnect'], 'unreadDisconnect', (err, data) ->
  amqp.publish 'chat.unread', data

Chat.on '*', (evt) ->
  console.log LOG, "Chat event [#{evt}] triggered"

# MESSAGEMANAGER ---------
MessageManager.on ['attachment', 'message'], 'broadcast', (err, data) ->
  # Broadcast
  if Config.options.allowEcho
    Chat.broadcast data.message if not err
  else
    Chat.broadcast data.message, data.connection if not err

  try
    # Tracking
    Tracking.trackMessage data
    # TODO TRACKING: time since last interaction from another role
  catch ex
    console.error LOG, "Tracking message exception:", (ex?.stack or ex)


MessageManager.on ['status'], 'statusUpdate', (err, data) ->
  msg = data.message
  Chat.updateUserSessionStatus data.user.id, msg.session, msg.data

MessageManager.on ['away'], 'awayUpdate', (err, data) ->
  data.user.isAway = data.message.data.isAway
  console.log data.user
  Chat.updateProfessionalList(
    null, Config.options.allowProfessionalList or false
  )
  Chat.updateSelfStatus(
    data.user
  )

MessageManager.on ['connect'], 'loadSessions', (err, data) ->
  Chat.loadSessions data.user, data.message.id if not err
  if data.user.role is 'professional'
    Chat.updateProfessionalList(
      null, Config.options.allowProfessionalList or false
    )
  else
    Chat.updateProfessionalList(
      data.connection, Config.options.allowProfessionalList or false
    )

MessageManager.on ['join'], 'loadSession', (err, data) ->
  Chat.loadSession data.user.id,
    data.message.session, data.message.id if not err

MessageManager.on '*', (evt) ->
  console.log LOG, "MessageManager event [#{evt}] triggered"

# AMQP ---------------------

# Connected and ready to publish
amqp.on 'connect', 'requestSessions', ->
  amqp.publish 'request.sessions.users', {}

# Attachment received
amqp.on 'chat.attachment', 'broadcast', (err, data) ->
  Chat.broadcast data

# Close received
amqp.on 'session.close', 'destroy', (err, data) ->
  console.log LOG, 'session.close', data
  Chat.destroy data.id

# Finish received
amqp.on 'session.finish', 'destroy2', (err, data) ->
  console.log LOG, 'session.finish', data
  msg =
    id: null
    type: 'reload'
    status: 1000
    data:
      type: 'session'
      target: data.sessionId
  for userId in data.clients
    Chat.notice msg, Database.userSockets.get userId

# Changed session's users list
amqp.on 'session.users', 'users', (err, data) ->
  sessionId = data.id
  userIds = data.userIds

  oldIds = Database.sessionUsers.get data.id

  # set session's users list
  Database.sessionUsers.set sessionId, userIds

  # remaining users get notified of changes
  msg =
    id: null
    type: 'reload'
    status: 1000
    data:
      type: 'session'
      target: sessionId
      participants: userIds

  for userId in oldIds when userId in userIds
    Chat.notice msg, Database.userSockets.get userId

  # users could join
  for userId in userIds when userId not in oldIds
    Database.userSessions.add userId, sessionId
    # Automatically send history
    Chat.loadSession userId, sessionId, null if not err

  # users must leave (kick'em!)
  for userId in oldIds when userId not in userIds
    Database.userSessions.remove userId, sessionId
    Chat.kick sessionId, [userId]

# Changed sessions' users list
amqp.on 'sessions.users', 'users', (err, data) ->
  _old = Database.sessionUsers.getIds()
  _new = Object.keys(data.sessions) #.map (id) -> parseInt id

  # save new
  Database.sessionUsers.load data.sessions
  Database.userSessions.loadFromSessions data.sessions

  # kick from old
  for sessionId of _old when sessionId not in _new
    Chat.kick sessionId

amqp.on 'sessions.pools', 'broadcast', (err, data) ->
  console.log LOG, 'sessions.pools', data.servicetypes
  msg =
    id: null
    type: 'update'
    status: 1000
    data: servicetypes: data.servicetypes
  Chat.notice msg, Database.userSockets.getProfessionals()

amqp.on '*', (evt) ->
  console.log LOG, "amqp event [#{evt}] triggered"

###
  WEBSOCKETS --------------------------------------------------------
###

server = http.createServer (request, response) ->
  console.log LOG, "Received request for #{request.url}"
  if request.url is '/ping'
    response.writeHead 200
    response.write 'pong'
  else
    response.writeHead 404
  response.end()

server.listen Config.ws.port, ->
  console.log LOG, "Server is listening on port #{Config.ws.port}"

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
  PapersPlease.request request
  .then (response) ->
    {request, session} = response
    Connect request, session, MessageManager
  .catch (err) ->
    console.warn LOG, "Failed connect request from #{request.origin}", err
    try
      request.reject()
    catch ex
