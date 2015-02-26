# Security checks (⌐■_■)
papersPlease = {
  request: (request) ->
    # TODO: check origin: request.origin
    # TODO: check auth
    return true

  message: (object) ->
    # TODO: check by type
    return true
}

module.exports = exports = papersPlease