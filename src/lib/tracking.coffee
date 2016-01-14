Keen = require 'keen-tracking'
Database = require './database'
config = require './config'

LOG = "Keen >"

# Module
module.exports = Tracking =
  _keen: null
  init: ->
    if config.keenProjectId
      console.log LOG, "Starting Keen"
      ###coffeelint-variable-scope-ignore###
      Tracking._keen = new Keen
        projectId: config.keenProjectId
        writeKey: config.keenWriteKey
      Tracking._keen.extendEvents ->
        keen:
          timestamp: new Date().toISOString()
        appName: config.appName

  onResponse: (log, err, res) ->
    if err
      console.error LOG, "Tracking error on #{log}", (err?.stack or err), res

  getServerStats: ->
    # Connections
    connections:
      all: Database.userSockets.count()
      clients: Database.userSockets.getClients()?.length or 0
      professionals: Database.userSockets.getProfessionals()?.length or 0
    # Online
    online:
      all: Database.users.count()
      clients: Database.users.countClients()
      professionals: Database.users.countProfessionals()

  # Tracks an event
  trackEvent: (ev, data) ->
    console.log LOG, "Tracking event #{ev}"
    try
      Tracking._keen?.recordEvent ev, data,
        Tracking.onResponse.bind(Tracking, ev)
    catch ex
      console.error LOG, "Exception tracking #{ev}", (ex?.stack or ex)

  trackMessage: (umc) ->
    message = umc.message
    # Session stats
    _sessionRoles = Database.sessionUsers.getUserRoles message.session
    _sessionUsers = count: {}
    for role, _users of _sessionRoles
      if _sessionRoles[role].length > 1
        _sessionUsers[role] = _users
      else
        _sessionUsers[role] = _users[0]
      _sessionUsers.count[role] = _users.length
    # Keen tracking
    data =
      user:
        id: umc.user.id
        role: umc.user.role
      session:
        id: message.session
        users: _sessionUsers
      message:
        id: message.id
        type: message.type
        timestamp: message.timestamp
    if message.type is 'attachment'
      data.message.length = 0
      # File
      file = message.data
      data.file =
        name: file.message
        type: file.type
        href: file.href
        size: file.size
    else
      data.message.length = message.data?.length or -1
    Tracking.trackEvent 'message', data

  trackConnection: (user, connectionDiff) ->
    _sockets = Database.userSockets.get(user.id)?.length or 0
    _online = 0
    # Detect new connection
    if connectionDiff is 1 and _sockets is 1
      _online = 1
    # Detect no connections
    else if _sockets is 0
      _online = -1

    data =
      user:
        id: user.id
        role: user.role
      userConnection:
        connection: connectionDiff
        online: _online
        connections: _sockets
    data.serverStats = Tracking.getServerStats()
    Tracking.trackEvent 'connection', data

# Attach initialization
if "function" is typeof Keen.ready
  Keen.ready Tracking.init
else
  Tracking.init()
