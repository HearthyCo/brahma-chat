URL = require 'url'

redisParts = URL.parse process.env.REDIS_PORT, true
amqpParts = URL.parse process.env.AMQP_PORT, true

config =
  ws:
    port: 1337
  redis:
    url: process.env.REDIS_PORT
    protocol: redisParts.protocol || 'tcp:'
    host: redisParts.hostname || 'localhost'
    port: redisParts.port || 6379
  amqp:
    url: process.env.AMQP_PORT
    protocol: amqpParts.protocol || 'amqp:'
    host: amqpParts.hostname || 'localhost'
    port: amqpParts.port
  secret: "7WMh?srdpHHKCKE]^=CrNTS:VIvtS4<r`:^aFp^bLMdCviInZd_Vtjv?XSITK?Jr"
  colors:
    client: [ 'magenta', 'purple', 'plum', 'orange' ]
    professional: [ 'red', 'green', 'blue' ]

module.exports = exports = config