defmodule Janus.Session.GenServer do
  use GenServer

  @doc """
  Starts the registry.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{url: nil, session: nil}, opts)
  end

  @doc """
  Looks up the bucket pid for `name` stored in `server`.
  Returns `{:ok, pid}` if the bucket exists, `:error` otherwise.
  """
  def start_session(pid) do
    GenServer.call(pid, :start_session)
  end

  ## Server Callbacks

  def init(state) do
    send(self(), :setup)
    {:ok, state}
  end

  # do any setup you need to here
  def handle_info(:setup, state) do
    janus_url = Application.get_env(:janus_phoenix_webrtc_demo, :janus_url)
    {:noreply, %{state | url: janus_url}}
  end

  def handle_call(:start_session, _from, state) do
    {:ok, session} = Janus.Session.start(state.url)

    {:ok, handle} =
      session
      |> Janus.Session.attach_plugin("janus.plugin.videoroom")

    {:reply, {session, handle}, state}
  end
end
