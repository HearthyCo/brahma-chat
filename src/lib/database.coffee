_ = require 'underscore'

# Local Data

oneOrMore = (arr, cb) ->
  _ret = []
  if 'object' is typeof arr
    for a in arr
      _ret.push cb(a)
  else
    _ret = cb(arr)
  return _ret

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
    if content not in dbObj[id]
      dbObj[id].push content
  remove: (id, item) ->
    if arguments.length is 1
      item = id
      id = @id
    ret = oneOrMore id, (a) ->
      _obj = dbObj[a]
      if _obj
        pos = _obj.indexOf item
        if pos >= 0
          _obj.splice pos, 1
          dbObj[a] = _obj
    return ret
  has: (id, item) ->
    if arguments.length is 1
      item = id
      id = @id
    item in (dbObj[id] or [])

# Lists of currently connected clients and sessions
dbObj = do ->
  # [sockets]
  connections = []
  # user.id: user
  users = {}
  # user.id: [sockets]
  userSockets = {}
  # session.id: [allowed users.ids]
  sessionUsers = {}

  iface =
    connections:
      add: (connection) ->
        connections.push(connection) - 1
      remove: (connectionIndex) ->
        connections.splice connectionIndex, 1

    users:
      add: (user) ->
        users[user.id] = user
      remove: (userId) ->
        users[userId] = undefined
        delete users[userId]
      get: (userId) ->
        users[userId]
      has: (userId) ->
        return if users[userId] then true else false
      getIds: -> Object.keys users

    # ------- user sockets
    userSockets: crud.call @, userSockets
    # ------- session users
    sessionUsers: crud.call @, sessionUsers

  iface.sessionUsers.getSockets = (id) ->
    online = iface.sessionUsers.getConnStates(id).online
    _.flatten(
      iface.userSockets.get userId for userId in online
    ) or []

  iface.sessionUsers.getConnStates = (id) ->
    allowed = iface.sessionUsers.get id
    connected = iface.users.getIds()
    offline = _.difference allowed, connected
    online = _.difference allowed, offline

    return {
      online: online
      offline: offline
    }

  return iface

module.exports = dbObj
