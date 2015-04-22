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
      _trigger 'ping', null,
        user: user, message: message

    # JOIN
    when 'session'
      if not PapersPlease.session message, user.id
        console.warn message.id, 'Sessions outdated', message.type,
          message.data
        _trigger 'session', new Error('Session outdated'),
          user: user, message: message
        return user.connection.sendUTF utils.mkResponse 4010, id

      user.sessions = message.data.sessions
      _trigger 'session', err,
        user: user, message: message


    # CONNECT
    when 'handshake'
      if not PapersPlease.handshake message
        console.warn message.id, 'Handshake failed signature',
          message.type, message.data
        _trigger 'handshake', new Error('Handshake failed signature'),
          user: user, message: message
        return user.connection.sendUTF utils.mkResponse 4010, id

      # Update user
      user.id = message.data.userId
      user.sessions = message.data.sessions or []
      # Add socket to user socket list
      Database.userSockets.add user.id, user.connection

      _trigger 'handshake', null,
        user: user, message: message

    # MESSAGE
    when 'message'
      if not PapersPlease.message message, user.sessions
        console.warn message.id, 'Forbidden session', message.type,
          message.data
        return user.connection.sendUTF utils.mkResponse 4010, id

      _trigger 'message', null,
        user: user, message: message

    # ATTACHMENT
    when 'attachment'
      if not PapersPlease.message message, user.sessions
        console.warn message.id, 'Forbidden session', message.type,
          message.data
        _trigger 'attachment', new Error('Forbidden session'),
          user: user, message: message
        return user.connection.sendUTF utils.mkResponse 4010, id

      _trigger 'attachment', null,
        user: user, message: message

# Events
_on = {}
_trigger = (ev, err, payload) ->
  _on[ev](err, payload) if _on[ev]

manager.on = (ev, callback) ->
  if 'object' is typeof ev
    ev.forEach (e) ->
      _on[e] = callback if 'function' is typeof callback
    return true
  else
    _on[ev] = callback if 'function' is typeof callback
  return _on[ev]

manager.off = (ev) ->
  if 'object' is typeof ev
    ev.forEach (e) ->
      _on[e] = undefined
      delete _on[e]
  else
    _on[ev] = undefined
    delete _on[ev]
