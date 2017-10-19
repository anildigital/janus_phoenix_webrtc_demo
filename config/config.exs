# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :janus_phoenix_webrtc_demo,
  ecto_repos: [JanusPhoenixWebrtcDemo.Repo]

# Configures the endpoint
config :janus_phoenix_webrtc_demo, JanusPhoenixWebrtcDemoWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "0kg7lX0MdkfYBfDMViEpLmVd6iA9Ax0FWt8YC55lKCwKFNoIj4V9KaMWUirU6fnQ",
  render_errors: [view: JanusPhoenixWebrtcDemoWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: JanusPhoenixWebrtcDemo.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
