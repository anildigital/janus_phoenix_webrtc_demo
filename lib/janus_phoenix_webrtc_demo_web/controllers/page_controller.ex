defmodule JanusPhoenixWebrtcDemoWeb.PageController do
  use JanusPhoenixWebrtcDemoWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
