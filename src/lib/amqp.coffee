amqplib = require 'amqplib'
_when = require 'when'

eventHandler = require('got-events')()

LOG = "AMQP >"

module.exports = amqp =
  config: {}
  exchange: 'amq.topic'
  keys: [
    'chat.attachment'
    'session.close', 'session.finish', 'session.users'
    'sessions.users', 'sessions.pools'
  ]

  _reconnections: 0
  connection: null
  channelR: null
  channelW: null

  #--- Setup
  connect: (config = amqp.config) ->
    amqplib
    .connect(config.url)
    .then (conn) ->
      amqp.connection = conn
      amqp.connection.on 'close', amqp.onConnectionClose
      amqp.connection.on 'error', amqp.onConnectionError
      _when.all [
        amqp._listen conn
        amqp._append conn
      ]
      .then ->
        amqp._reconnections = 0
        console.info LOG, "Connected"
        eventHandler.trigger.call amqp, 'connect', null, amqp
    .then null, amqp.onConnectFail

  _listen: (conn) ->
    conn.createChannel().then (ch) ->
      amqp.channelR = ch
      amqp.channelR.assertExchange amqp.exchange, 'topic', durable: true
      .then ->
        amqp.channelR.assertQueue '', exclusive: true
      .then (qok) ->
        queue = qok.queue
        binds = _when.map amqp.keys, (key) ->
          amqp.channelR.bindQueue queue, amqp.exchange, key
        binds.then -> queue
      .then (queue) ->
        amqp.channelR.consume queue, amqp.onReceive
      .then ->
        console.info LOG, "Listen ready"
        eventHandler.trigger.call amqp, 'listenReady', null, amqp

  _append: (conn) ->
    conn.createConfirmChannel().then (ch) ->
      amqp.channelW = ch
      amqp.channelW.on 'return', amqp.onReturn
    .then ->
      console.info LOG, "Append ready"
      eventHandler.trigger.call amqp, 'appendReady', null, amqp

  reconnect: ->
    amqp._reconnections++
    root.setTimeout ->
      amqp.connect amqp.config
    , Math.min(1000 * amqp._reconnections, 5000)

  #--- Internal events
  onConnectFail: (err) ->
    amqp.reconnect()
    console.error LOG, "Retry #{amqp._reconnections} after:",
      (err.stack or err)
    eventHandler.trigger.call amqp, 'connectFail', null, amqp

  onReturn: (err) ->
    console.warn LOG, "Message returned:", err
    # amqp.connection?.close()

  onConnectionClose: ->
    amqp.reconnect()
    console.error LOG, "Connection closed. Retry #{amqp._reconnections}."

  onConnectionError: (err) ->
    console.error LOG, "Connection error:", (err.stack or err)
    amqp.onConnectFail err

  onReceive: (msg) ->
    key = msg.fields.routingKey
    try
      data = JSON.parse msg.content.toString()
    catch ex
      console.error LOG, "onReceive. JSON.parse:", (ex?.stack or ex)

    eventHandler.trigger.call amqp, key, null, data

  onProcessed: (err) ->
    console.log LOG, "Message processed. Err:", err

  publish: (key, payload) ->
    if "string" isnt typeof payload
      payload = JSON.stringify payload

    amqp.channelW.publish amqp.exchange, key, new root.Buffer(payload), {},
      amqp.onProcessed

    console.log LOG, "Published", amqp.exchange, key, payload
    eventHandler.trigger.call amqp, key, null, payload

amqp.on = eventHandler.on
amqp.off = eventHandler.off