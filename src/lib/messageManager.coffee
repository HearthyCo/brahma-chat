Database = require './database'
PapersPlease = require './papersPlease'
utils = require './utils'

eventHandler = require('got-events')()

# MWAHAHAHA!
When = require 'when'
Promise = When.promise

LOG = "MMan >"

module.exports = manager = (umc) ->

  message = umc.message
  user = umc.user
  connection = umc.connection

  id = "#{message.id}"

  umc = user: user, message: message, connection: connection

  console.log LOG, "@#{user?.id or '?'}", message.type, message.id

  # Save Promise in `end`
  end = switch message.type
    # PING? PONG!
    when 'ping'
      PapersPlease.auth umc
      .then ->
        connection.sendUTF utils.mkResponse 2000, id, 'pong'
        eventHandler.trigger 'ping', null, umc

    # CONNECT
    when 'handshake'
      PapersPlease.handshake umc
      .then ->
        # Update user
        user.id = message.data.userId
        user.role = message.data.userRole
        # Add user
        Database.users.add user
        # Add socket to user socket list
        Database.userSockets.add user.id, connection
        eventHandler.trigger 'handshake', null, umc

    # JOIN
    when 'join'
      PapersPlease.join umc
      .then ->
        eventHandler.trigger 'join', null, umc

    # MESSAGE
    when 'message'
      if message.data.message is '/status'
        console.info LOG, "user", user
        if user
          console.info LOG, "sessions", Database.userSessions.get(user.id)
        console.info LOG, "sessionUsers", Database.sessionUsers.getAll()
        console.info LOG, "userSessions", Database.userSessions.getAll()
        console.info LOG, "users", Database.users.getAll()
        console.info LOG, (((userId) ->
          _user = Database.users.get userId

          id: userId
          role: _user?.role or "Offline"

          ) userId for userId in (Database.sessionUsers.get message.session))
        When.resolve null
      else
        PapersPlease.message umc
        .then ->
          eventHandler.trigger 'message', null, umc

    # ATTACHMENT
    when 'attachment'
      PapersPlease.message umc
      .then ->
        eventHandler.trigger 'attachment', null, umc

    else
      console.error LOG, "@#{user?.id or '?'} ##{message.session or '?'}",
        "Invalid type: #{message.type}",
        message.type, message.id, message.data
      When.resolve null

  # Catches every error
  end.catch (err) ->
    console.warn LOG, "@#{user?.id or '?'} ##{message.session}",
      "#{message.type}",
      err, message.type, message.id, message.data
    connection.sendUTF utils.mkResponse 4010, id
    eventHandler.trigger message.type, err, umc

# Public events methods
manager.on = eventHandler.on
manager.off = eventHandler.off
