# TODO: Convert sessionUsers and userSessions to Redis

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
  # full load
  load: (dump) ->
    dbObj = dump or {}
  # collection
  getIds: -> Object.keys(dbObj).map (id) -> parseInt id
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
database = do ->
  # [sockets]
  connections = []
  # user.id: user
  users = {}
  # user.id: [sockets]
  userSockets = {}
  # session.id: [allowed users.ids]
  sessionUsers = {}
  # user.id: [allowed sessions.ids]
  userSessions = {}

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
      getIds: -> Object.keys(users).map (id) -> parseInt id
      getAll: -> users

    # ------- user sockets
    userSockets: crud.call @, userSockets
    # ------- session users
    sessionUsers: crud.call @, sessionUsers
    # ------- user sessions
    userSessions: crud.call @, userSessions

  # ------- custom

  # Get connected professionals count
  iface.users.countProfessionals = ->
    iface.users.getProfessionals()?.length

  # Get connected professionals list
  iface.users.getProfessionals = ->
    (id for id, info of users when info.role is 'professional')

  # Get sockets from sessionId
  iface.sessionUsers.getSockets = (id) ->
    online = iface.sessionUsers.getConnStates(id).online
    _.flatten(
      iface.userSockets.get userId for userId in online
    ) or []

  # Get userIds online/offline in sessionId
  iface.sessionUsers.getConnStates = (id) ->
    allowed = iface.sessionUsers.get id
    connected = iface.users.getIds()
    offline = _.difference allowed, connected
    online = _.difference allowed, offline

    return {
      online: online
      offline: offline
    }

  # Get professional's userIds
  iface.userSockets.getProfessionals = ->
    professionals = (id for id, info of users when info.role is 'professional')
    sockets = []
    for uid in professionals
      for socket in userSockets[uid]
        sockets.push socket
    sockets

  # Get client's userIds
  iface.userSockets.getClients = ->
    clients = (id for id, info of users when info.role is 'client')
    sockets = []
    for uid in clients
      for socket in userSockets[uid]
        sockets.push socket
    sockets

  # Set [user].sessions from sessionUsers arrays
  iface.userSessions.loadFromSessions = (_sessionUsers) ->
    _sessionUsers = _sessionUsers or iface.sessionUsers.getAll()
    cache = {}
    for sessionId, usersAllowed of _sessionUsers
      for userId in usersAllowed
        cache[userId] = [] if not cache[userId]
        cache[userId].push parseInt(sessionId)

    iface.userSessions.load cache

  return iface

module.exports = database
