defmodule BrahmaChat.Router do
  use Phoenix.Router

  socket "/ws", Chat do
    channel "sessions:*", SessionChannel
  end

  pipeline :api do
    plug :accepts, ~w(json)
  end

  scope "/", BrahmaChat do
    pipe_through :api # Use the default browser stack

    get "/", PageController, :index
  end
end
