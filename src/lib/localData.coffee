# Local Data

# Manage object lists
crud =
  # collection
  get: (id) -> this[id] or []
  set: (id, content) -> this[id] = content or []
  destroy: (id) ->
    this[id] = undefined
    delete this[id]
  # item
  add: (id, content) ->
    this[id] = this[id] or []
    this[id].push content
  remove: (id, item) ->
    ret = []
    _this = this[id]
    if _this
      pos = _this.indexOf item
      if pos >= 0
        ret = _this.splice pos, 1
        this[id] = _this
    return ret
  has: (id, item) ->
    item in (this[id] or [])

# Lists of currently connected clients and sessions
db = do ->
  clients = []
  # opened sockets
  sockets = {}
  # list of currently connected sessions
  sessions = {}

  iface =
    addClient: (client) ->
      clients.push(client) - 1
    removeClient: (clientIndex) ->
      clients.slice clientIndex, 1

    # ------- user sockets
    getUserSockets: (userId) ->
      crud.get.apply sockets, arguments
    setUserSockets: (userId, socket) ->
      crud.set.apply sockets, arguments
    removeUserSockets: (userId) ->
      crud.destroy.apply sockets, arguments
    addUserSocket: (userId, socket) ->
      crud.add.apply sockets, arguments
    removeUserSocket: (userId, socket) ->
      crud.remove.apply sockets, arguments

    # ------- session sockets
    getSessionSockets: (sessionId) ->
      crud.get.apply sessions, arguments
    setSessionSockets: (sessionId, content) ->
      crud.set.apply sessions, arguments
    removeSessionSockets: (sessionId) ->
      crud.destroy.apply sessions, arguments
    sessionHasSocket: (sessionId, socket) ->
      crud.has.apply sessions, arguments
    addSessionSocket: (sessionId, socket) ->
      crud.add.apply sessions, arguments
    removeSessionSocket: (sessionId, socket) ->
      crud.remove.apply sessions, arguments

  return iface

module.exports = db