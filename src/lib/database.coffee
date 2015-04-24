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
      getIds: -> Object.keys users

    # ------- user sockets
    userSockets: crud.call @, userSockets
    # ------- session users
    sessionUsers: crud.call @, sessionUsers

  iface.sessionUsers.getSockets = (id) ->
    (iface.userSockets.get userId for userId in iface.sessionUsers.get(id))

  iface.userSockets.getProfessionals = ->
    professionals = (id for id, info of users when info.role is 'professional')
    sockets = []
    for uid in professionals
      for socket in userSockets[uid]
        sockets.push socket
    sockets

  return iface

module.exports = dbObj
