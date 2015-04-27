Database = require './database'
Chat = require './chatActions'
PapersPlease = require './papersPlease'
utils = require './utils'

eventHandler = require('got-events')()

LOG = "MMan >"

module.exports = manager = (message, user, connection) ->

  id = "#{message.id}"

  payback = user: user, message: message, connection: connection

  console.log LOG, "@#{user?.id or '?'}", message.type, message.id

  switch message.type
    # PING? PONG!
    when 'ping'
      connection.sendUTF utils.mkResponse 2000, id, 'pong'
      eventHandler.trigger 'ping', null, payback

    # CONNECT
    when 'handshake'
      if not PapersPlease.handshake message
        console.warn LOG, "@#{user?.id or '?'} Handshake failed signature",
          message.type, message.id, message.data
        eventHandler.trigger 'handshake',
          new Error('Handshake failed signature'), payback
        return connection.sendUTF utils.mkResponse 4010, id

      # Update user
      user.id = message.data.userId
      user.role = message.data.userRole
      # Add user
      Database.users.add user
      # Add socket to user socket list
      Database.userSockets.add user.id, connection

      eventHandler.trigger 'handshake', null, payback

    # MESSAGE
    when 'message'
      if message.data.message is '/status'
        console.info LOG, "user", user
        console.info LOG, "sessions", Database.userSessions.get(user.id)
        console.info LOG, "sessionUsers", Database.sessionUsers.getAll()
        console.info LOG, "userSessions", Database.userSessions.getAll()
        console.info LOG, "users", Database.users.getAll()
        console.info LOG, (((userId) ->
          user = Database.users.get userId

          id: userId
          role: user?.role or "Offline"

          ) userId for userId in (Database.sessionUsers.get message.session))

      if not PapersPlease.message message, Database.userSessions.get(user.id)
        console.warn LOG, "@#{user?.id or '?'} Forbidden ##{message.session}",
          message.type, message.id, message.data
        return connection.sendUTF utils.mkResponse 4010, id

      eventHandler.trigger 'message', null, payback

    # ATTACHMENT
    when 'attachment'
      if not PapersPlease.message message, Database.userSessions.get(user.id)
        console.warn LOG, "@#{user?.id or '?'} Forbidden ##{message.session}",
          message.type, message.id, message.data
        eventHandler.trigger 'attachment',
          new Error('Forbidden session'), payback
        return connection.sendUTF utils.mkResponse 4010, id

      eventHandler.trigger 'attachment', null, payback

# Public events methods
manager.on = eventHandler.on
manager.off = eventHandler.off
