# Local Data

# Manage object lists
crud = (dbObj) ->
  # collection
  get: (id = @id) -> this[id] or []
  set: (id, content) ->
    if arguments.length is 1
      content = id
      id = @id
    this[id] = content or []
  destroy: (id) ->
    this[id] = undefined
    delete this[id]
  # item
  add: (id, content) ->
    if arguments.length is 1
      content = id
      id = @id
    dbObj[id] = dbObj[id] or []
    dbObj[id].push content
  remove: (id, item) ->
    if arguments.length is 1
      item = id
      id = @id
    ret = []
    _obj = dbObj[id]
    if _obj
      pos = _obj.indexOf item
      if pos >= 0
        ret = _obj.splice pos, 1
        dbObj[id] = _obj
    return ret
  has: (id, item) ->
    if arguments.length is 1
      item = id
      id = @id
    item in (dbObj[id] or [])

# Lists of currently connected clients and sessions
dbObj = do ->
  clients = []
  # opened sockets
  sockets = {}
  # list of currently connected sessions
  sessions = {}

  iface =
    client:
      add: (client) ->
        clients.push(client) - 1
      remove: (clientIndex) ->
        clients.slice clientIndex, 1

    # ------- user sockets
    userSockets:
      get: (userId) ->
        crud(sockets).get.apply @, [userId]
      set: (userId, socket) ->
        crud(sockets).set.apply @, [userId, socket]
      destroy: (userId) ->
        crud(sockets).destroy.apply @, [userId]
      add: (userId, socket) ->
        crud(sockets).add.apply @, [userId, socket]
      remove: (userId, socket) ->
        crud(sockets).remove.apply @, [userId, socket]

    # ------- session sockets
    sessionSockets:
      get: (sessionId) ->
        crud(sockets).get.apply @, [sessionId]
      set: (sessionId, content) ->
        crud(sockets).set.apply @, [sessionId, content]
      destroy: (sessionId) ->
        crud(sockets).destroy.apply @, [sessionId]
      has: (sessionId, socket) ->
        crud(sockets).has.apply @, [sessionId, socket]
      add: (sessionId, socket) ->
        crud(sockets).add.apply @, [sessionId, socket]
      remove: (sessionId, socket) ->
        crud(sockets).remove.apply @, [sessionId, socket]

  return iface

module.exports = dbObj
