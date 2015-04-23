# Local Data

# Manage object lists
crud = (dbObj) ->
  # collection
  getIds: -> Object.keys dbObj
  getAll: -> dbObj
  get: (id = @id) -> dbObj[id] or []
  set: (id, content) ->
    if arguments.length is 1
      content = id
      id = @id
    dbObj[id] = content or []
  destroy: (id) ->
    dbObj[id] = undefined
    delete dbObj[id]
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
  # [sockets]
  clients = []
  # user: [sockets]
  userSockets = {}
  # session: [sockets]
  sessionSockets = {}
  # session: [allowed users]
  sessionUsers = {}

  iface =
    client:
      add: (client) ->
        clients.push(client) - 1
      remove: (clientIndex) ->
        clients.slice clientIndex, 1

    # ------- user sockets
    userSockets: crud.call @, userSockets
    # ------- session sockets
    sessionSockets: crud.call @, sessionSockets
    # ------- session users
    sessionUsers: crud.call @, sessionUsers

  return iface

module.exports = dbObj
