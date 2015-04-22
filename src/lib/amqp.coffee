amqplib = require 'amqplib'
all = (require 'when').all

module.exports = amqp =
  config: {}
  exchange: 'amq.topic'
  keys: ['chat.attachment', 'session.close']

  _reconnections: 0
  connection: null
  channelR: null
  channelW: null

  #--- Setup
  connect: (config = amqp.config) ->
    amqplib.connect(config.url).then (conn) ->
      amqp.connection = conn
      amqp._listen conn
      amqp._append conn
      amqp._reconnections = 0
    .then null, amqp.onConnectFail

  _listen: (conn) ->
    conn.createChannel().then (ch) ->
      amqp.channelR = ch
      amqp.channelR.assertExchange amqp.exchange, 'topic', durable: true
      .then ->
        amqp.channelR.assertQueue '', exclusive: true
      .then (qok) ->
        queue = qok.queue
        t = all amqp.keys.map (key) ->
          amqp.channelR.bindQueue queue, amqp.exchange, key
        t.then -> queue
      .then (queue) ->
        amqp.channelR.consume queue, amqp.onReceive
      .then ->
        console.info 'AMQP listening'

  _append: (conn) ->
    conn.createConfirmChannel().then (ch) ->
      amqp.channelW = ch
      amqp.channelW.on 'return', amqp.onReturn

  #--- Internal events
  onConnectFail: (err) ->
    # 10 retries
    if amqp._reconnections < 9
      amqp._reconnections++
      console.warn "AMQP. Retry #{amqp._reconnections} after:", err
      process.nextTick ->
        amqp.connect amqp.config
    else
      console.error 'AMQP. No more retries after:', err

  onReturn: (err) ->
    console.warn "AMQP. Message returned:", err
    @connection?.close()

  onReceive: (msg) ->
    key = msg.fields.routingKey
    try
      data = JSON.parse msg.content.toString()
    catch ex
      console.error "AMQP. onReceive. JSON.parse:", ex

    if _on[key]
      _on[key].call amqp, null, data
    else
      console.log "AMQP. Unknown event:", key

  onProcessed: (err) ->
    console.log "AMQP. Message processed", err


  publish: (key, payload) ->
    if "string" is not typeof payload
      payload = JSON.stringify payload

    amqp.channelW.publish amqp.exchange, key, new Buffer(payload), {},
      amqp.onProcessed

# Events
_on = {}
_trigger = (ev, err, payload) ->
  _on[ev](err, payload) if _on[ev]

amqp.on = (ev, callback) ->
  if 'object' is typeof ev
    ev.forEach (e) ->
      _on[e] = callback if 'function' is typeof callback
    return true
  else
    _on[ev] = callback if 'function' is typeof callback
  return _on[ev]

amqp.off = (ev) ->
  if 'object' is typeof ev
    ev.forEach (e) ->
      _on[e] = undefined
      delete _on[e]
  else
    _on[ev] = undefined
    delete _on[ev]
