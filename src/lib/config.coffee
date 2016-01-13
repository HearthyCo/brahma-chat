URL = require 'url'

# Server configuration
options =
  allowEcho: true
  allowProfessionalList: true

# REDIS
redis_env = process.env.REDIS_URL or
  process.env.REDIS_PORT or
  'tcp://localhost:6379'
redis_url = URL.parse redis_env, true

# AMQP
amqp_env = process.env.RABBITMQ_URL or
  process.env.AMQP_PORT or
  'amqp://localhost:5672'
amqp_url = URL.parse amqp_env, true

# Protocols
redis_url.protocol = 'redis:'
amqp_url.protocol = 'amqp:'

config =
  ws:
    port: process.env.PORT or 1337
  redis:
    url: URL.format redis_url
    host: redis_url.hostname
    port: redis_url.port
  amqp:
    url: URL.format amqp_url
    host: amqp_url.hostname
    port: amqp_url.port
  secret: 'will grandfather hurt spider'
  colors:
    client: [ 'blue', 'purple', 'plum', 'orange' ]
    professional: [ 'red', 'green', 'magenta' ]
  options: options
  # Keen
  appName: 'client'
  keenProjectId: '56960698672e6c74d2303b30'
  keenWriteKey: 'aefd4f2122af136a7aab07471d084a4a2\
b590001a608502b4550b9c2133e5afda4\
8bd6d173ca9e5eb24891361913d264061\
ed14d758d85e22a2481af6208b160dfc4\
200adab2954b40412fb3c19b0e12664f3\
99a65f990e6619b41f0bf81b540'

module.exports = exports = config