Database = require './Database'
Chat = require './ChatActions'
PapersPlease = require './PapersPlease'
utils = require './utils'

eventHandler = require('simple-events')()

module.exports = manager = (message, user) ->

  id = message.id + ''

  console.log message.type, message.id, message
  switch message.type
    # PING? PONG!
    when 'ping'
      user.connection.sendUTF utils.mkResponse 2000, id, 'pong'
      eventHandler.trigger 'ping', null,
        user: user, message: message

    # JOIN
    when 'session'
      if not PapersPlease.session message, user.id
        console.warn message.id, 'Sessions outdated', message.type,
          message.data
        eventHandler.trigger 'session', new Error('Session outdated'),
          user: user, message: message
        return user.connection.sendUTF utils.mkResponse 4010, id

      user.sessions = message.data.sessions
      eventHandler.trigger 'session', null,
        user: user, message: message

    # CONNECT
    when 'handshake'
      if not PapersPlease.handshake message
        console.warn message.id, 'Handshake failed signature',
          message.type, message.data
        eventHandler.trigger 'handshake',
          new Error('Handshake failed signature'),
          user: user, message: message
        return user.connection.sendUTF utils.mkResponse 4010, id

      # Update user
      user.id = message.data.userId
      user.sessions = message.data.sessions or []
      # Add socket to user socket list
      Database.userSockets.add user.id, user.connection

      eventHandler.trigger 'handshake', null,
        user: user, message: message

    # MESSAGE
    when 'message'
      if not PapersPlease.message message, user.sessions
        console.warn message.id, 'Forbidden session', message.type,
          message.data
        return user.connection.sendUTF utils.mkResponse 4010, id

      eventHandler.trigger 'message', null,
        user: user, message: message

    # ATTACHMENT
    when 'attachment'
      if not PapersPlease.message message, user.sessions
        console.warn message.id, 'Forbidden session', message.type,
          message.data
        eventHandler.trigger 'attachment', new Error('Forbidden session'),
          user: user, message: message
        return user.connection.sendUTF utils.mkResponse 4010, id

      eventHandler.trigger 'attachment', null,
        user: user, message: message

# Public events methods
manager.on = eventHandler.on
manager.off = eventHandler.off
