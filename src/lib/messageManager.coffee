Database = require './Database'
Chat = require './ChatActions'
PapersPlease = require './PapersPlease'
utils = require './utils'

module.exports = manager = (message, user) ->

  id = message.id + ''

  console.log message.type, message.id, message
  switch message.type
    # PING? PONG!
    when 'ping'
      user.connection.sendUTF utils.mkResponse 2000, id, 'pong'

    # JOIN
    when 'session'
      if not PapersPlease.session message, user.id
        console.warn message.id, 'Sessions outdated', message.type,
          message.data
        return user.connection.sendUTF utils.mkResponse 4010, id

      user.sessions = message.data.sessions
      Chat.loadSessions user, (err, history) ->
        if not err
          user.connection.sendUTF utils.mkResponse 2000, id, 'joined', null,
            messages: history
        else
          console.error "Error loading join user sessions", err

    # CONNECT
    when 'handshake'
      if not PapersPlease.handshake message
        console.warn message.id, 'Handshake failed signature',
          message.type, message.data
        return user.connection.sendUTF utils.mkResponse 4010, id

      # Update user
      user.id = message.data.userId
      user.sessions = message.data.sessions or []

      # Add socket to user socket list
      Database.userSockets.add user.id, user.connection

      Chat.loadSessions user, (err, history) ->
        if not err
          user.connection.sendUTF utils.mkResponse 2000, id, 'granted', null,
            messages: history
        else
          console.error "Error loading handshake user sessions", err

    # MESSAGE
    when 'message'
      if not PapersPlease.message message, user.sessions
        console.warn message.id, 'Forbidden session', message.type,
          message.data
        return user.connection.sendUTF utils.mkResponse 4010, id

      Chat.broadcast message

    # ATTACHMENT
    when 'attachment'
      if not PapersPlease.message message, user.sessions
        console.warn message.id, 'Forbidden session', message.type,
          message.data
        return user.connection.sendUTF utils.mkResponse 4010, id

      Chat.broadcast message
