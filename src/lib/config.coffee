URL = require 'url'

redis_port = process.env.REDIS_PORT || 'tcp://localhost:6379'
amqp_port = process.env.AMQP_PORT || 'amqp://localhost:5672'
redisParts = URL.parse redis_port, true
amqpParts = URL.parse amqp_port, true

config =
  ws:
    port: process.env.PORT || 1337
  redis:
    host: redisParts.hostname
    port: redisParts.port
  amqp:
    url: URL.format protocol: 'amqp:', hostname: amqpParts.hostname, port: amqpParts.port
  secret: "7WMh?srdpHHKCKE]^=CrNTS:VIvtS4<r`:^aFp^bLMdCviInZd_Vtjv?XSITK?Jr"
  colors:
    client: [ 'magenta', 'purple', 'plum', 'orange' ]
    professional: [ 'red', 'green', 'blue' ]

module.exports = exports = config