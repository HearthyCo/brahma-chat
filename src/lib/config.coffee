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

module.exports = exports = config