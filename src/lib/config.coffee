URL = require 'url'

# REDIS
redis_env = process.env.REDIS_PORT || 'tcp://localhost:6379'
redis = URL.parse redis_env, true

# AMQP
amqp_env = process.env.AMQP_PORT || 'amqp://localhost:5672'
amqp = URL.parse amqp_env, true

# Protocol defaults to amqp:
amqp.protocol = 'amqp:'

config =
  ws:
    port: process.env.PORT || 1337
  redis:
    host: redis.hostname
    port: redis.port
  amqp:
    url: URL.format amqp
  secret: "7WMh?srdpHHKCKE]^=CrNTS:VIvtS4<r`:^aFp^bLMdCviInZd_Vtjv?XSITK?Jr"
  colors:
    client: [ 'magenta', 'purple', 'plum', 'orange' ]
    professional: [ 'red', 'green', 'blue' ]

module.exports = exports = config