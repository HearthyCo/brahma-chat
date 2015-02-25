use Mix.Config

# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to the previous section:
#
#  config:brahma_chat, BrahmaChat.Endpoint,
#    ...
#    https: [port: 443,
#            keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#            certfile: System.get_env("SOME_APP_SSL_CERT_PATH")]
#
# Where those two env variables point to a file on
# disk for the key and cert.

# ## Using releases
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start the server for all endpoints:
#
#     config :phoenix, :serve_endpoints, true
#
# Alternatively, you can configure exactly which server to
# start per endpoint:
#
#     config :brahma_chat, BrahmaChat.Endpoint, server: true
#

config :brahma_chat, BrahmaChat.Endpoint,
  url: [host: "example.com"],
  http: [port: System.get_env("PORT")],
  secret_key_base: "uVymdj8bG0rgYid3ds8IgK1x7MhmT/jdKJf2B7mY1XUyJG/Xq4EhosAHe023vfNP"

# Do not pring debug messages in production
config :logger, level: :info
