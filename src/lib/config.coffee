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
  keenProjectId: '568e343f59949a717d66f555'
  keenWriteKey: 'b5ed36456092145dc8e0be063fbe617c146bcf0\
cafc7f30b2fe02bcc952000328b549cf8368d7113d0b8dde747cf51f\
18ada5497ff75be2c3e6c9c2d909a920185653b12558750444d2c715\
7fef031eb37b9e9232a6515529cb7660adbcec6a37b3523b8c6d3d33\
32394431d253f887b'


module.exports = exports = config