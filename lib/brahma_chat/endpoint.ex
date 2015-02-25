defmodule BrahmaChat.Endpoint do
  use Phoenix.Endpoint, otp_app: :brahma_chat

  # Serve at "/" the given assets from "priv/static" directory
  plug Plug.Static,
    at: "/", from: :brahma_chat,
    only: ~w(css images js favicon.ico robots.txt)

  plug Plug.Logger

  # Code reloading will only work if the :code_reloader key of
  # the :phoenix application is set to true in your config file.
  plug Phoenix.CodeReloader

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session,
    store: :cookie,
    key: "_brahma_chat_key",
    signing_salt: "PZVpsEEg",
    encryption_salt: "W25u+cJm"

  plug :router, BrahmaChat.Router
end
