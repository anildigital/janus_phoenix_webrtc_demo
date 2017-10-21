defmodule JanusPhoenixWebrtcDemoWeb.RoomChannel do
  use JanusPhoenixWebrtcDemoWeb, :channel

  def join("room:user:" <> user_id, payload, socket) do
    if authorized?(payload) do
      socket = assign(socket, :user_id, user_id)

      IO.puts("Personal channel #{user_id} join successful")

      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # @decorate channel_action()
  def handle_in("offer", %{"jsep" => %{"body" => jsep}}, socket) do
    IO.puts("Got offer from client")
    IO.inspect(jsep)
    {session, handle} = setup_janus(jsep)

    socket = assign(socket, :session, session)

    ConCache.put(:app_cache, handle, socket.assigns[:user_id])
    ConCache.put(:app_cache, session, socket.assigns[:user_id])

    RoomCall.start(handle, jsep)

    socket = assign(socket, :publisher_handle, handle)

    {:noreply, socket}
  end

  # broadcast to everyone in the current topic (standup_room:lobby).
  # @decorate channel_action()
  def handle_in(
        "answer",
        %{"jsep" => %{"body" => jsep}, "remote_handle_id" => remote_handle_id},
        socket
      ) do
    IO.puts("Got answer from client")
    IO.inspect(jsep)
    IO.puts("Remote handle id answer #{inspect(remote_handle_id)}")

    handle = ConCache.get(:handle_cache, remote_handle_id)

    RoomCall.answer(handle, jsep)

    {:noreply, socket}
  end

  # @decorate channel_action()
  def handle_in(
        "ice",
        %{"ice" => %{"body" => ice_candidate}, "remote_handle_id" => remote_handle_id},
        socket
      ) do
    IO.puts("Got ice candidate")
    IO.inspect(ice_candidate)

    # If id is passed, retrieve handle from it. Otherwise, use socket assigned one
    handle =
      if remote_handle_id do
        IO.puts("Remote handle id ice #{inspect(remote_handle_id)}")
        ConCache.get(:handle_cache, remote_handle_id)
      else
        socket.assigns[:publisher_handle]
      end

    if handle do
      RoomCall.trickle(handle, ice_candidate)
    end

    {:noreply, socket}
  end

  # @decorate channel_action()
  def handle_in("stop", %{}, socket) do
    handle_in("stop", %{"stop_recording" => false, "user_id" => nil, "name" => nil}, socket)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end

  defp setup_janus(jsep) do
    # Create session
    janus_url = Application.get_env(:janus_phoenix_webrtc_demo, :janus_url)
    {:ok, session} = Janus.Session.start(janus_url)

    {:ok, handle} =
      session
      |> Janus.Session.attach_plugin("janus.plugin.videoroom")

    # Add handler for session
    Janus.Session.add_handler(session, SessionCall, %{:jsep => jsep})

    # Add handler for plugin
    Janus.Plugin.add_handler(handle, RoomCall, %{:jsep => jsep})

    {session, handle}
  end

  # def join("room:lobby", payload, socket) do
  #   if authorized?(payload) do
  #     {:ok, socket}
  #   else
  #     {:error, %{reason: "unauthorized"}}
  #   end
  # end

  # # Channels can be used in a request/response fashion
  # # by sending replies to requests from the client
  # def handle_in("ping", payload, socket) do
  #   {:reply, {:ok, payload}, socket}
  # end

  # # It is also common to receive messages from the client and
  # # broadcast to everyone in the current topic (room:lobby).
  # def handle_in("shout", payload, socket) do
  #   broadcast socket, "shout", payload
  #   {:noreply, socket}
  # end

  # # Add authorization logic here as required.
  # defp authorized?(_payload) do
  #   true
  # end
end
