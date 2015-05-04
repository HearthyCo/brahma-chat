http = require 'http'
utils = require './utils'
_when = require 'when'

PapersPlease = require './papersPlease'
Database = require './database'

LOG = "Conn >"

module.exports = connect = (request, MessageManager) ->
  connection = request.accept null, request.origin
  index = Database.connections.add connection

  # User data initialization
  user =
    id: null
    role: 'client'

  console.log LOG, "Connection #{connection.remoteAddress} accepted."

  connection.on 'message', (messageString) ->
    # check if messageString is valid
    if messageString.type is 'utf8'
      # JSON messageString
      try
        messages = JSON.parse messageString.utf8Data
      catch ex
        console.warn LOG, "@#{user?.id or '?'} JSON.parse:", ex
        return connection.sendUTF utils.mkResponse 4000

      if Object.prototype.toString.call(messages) isnt '[object Array]'
        messages = [messages]

      for message in messages
        umc = user: user, message: message, connection: connection
        do (umc) ->
          PapersPlease.auth umc
          .then ->
            PapersPlease.required umc
          .then ->
            # set author
            umc.message.author = umc.user.id
            # Send to MessageManager
            MessageManager umc
          .catch (err) ->
            console.warn LOG, "@#{umc.user?.id or '?'}", err,
              umc.message.type, umc.message.id, umc.message.data
            if err is 'Unauthorized before handshake'
              umc.connection.sendUTF utils.mkResponse 4010
            else
              umc.connection.sendUTF utils.mkResponse 4030

    else
      console.warn LOG, "@#{user?.id or '?'}", 'Unknown string type:',
        messageString.type

  connection.on 'close', (reasonCode, description) ->
    # remove connection
    Database.connections.remove index

    if user.id
      console.log LOG, "@#{user?.id or '?'} disconnected",
        "(#{connection.remoteAddress})",
        reasonCode, description

      # remove user socket from list
      Database.userSockets.remove user.id, connection

      # Remove user if offline
      if not Database.userSockets.get(user.id).length
        Database.users.remove user.id

  return connection