checkSignature = require './checkSignature'

# Security checks (⌐■_■)
papersPlease = {
  request: (request) ->
    # TODO: check origin: request.origin
    # TODO: check auth
    return true

  handshake: (object) ->
    if not object.data
      return false
    data = object.data
    if not data._userId_sign or not data._sessions_sign
      return false

    if not checkSignature data.userId, data._userId_sign
      return false

    if not checkSignature JSON.stringify(data.sessions), data._sessions_sign
      return false

    return true

  message: (object) ->
    # TODO: check by type
    return true
}

module.exports = exports = papersPlease