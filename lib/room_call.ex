defmodule RoomCall do
  use GenEvent

  def start(plugin_pid, jsep) do
    # ConCache.get(:app_cache, plugin_pid)
    user_id = random_string(10)

    # FIXME
    room_id = 3_800_664_449_808_512

    session_id = get_session_id(plugin_pid)
    ConCache.put(:app_cache, %{session_id: session_id, type: "room_id"}, room_id)

    # Send publisher request
    Janus.Plugin.message(plugin_pid, %{
      display: user_id,
      ptype: "publisher",
      request: "join",
      room: room_id
    })

    # Send configure request
    Janus.Plugin.message(plugin_pid, %{audio: true, request: "configure", video: true}, jsep)

    {:ok, room_id}
  end

  def start_publish(plugin_pid, jsep) do
    Janus.Plugin.message(plugin_pid, %{audio: true, request: "configure", video: true}, jsep)
  end

  def unpublish(plugin_pid) do
    Janus.Plugin.message(plugin_pid, %{request: "unpublish"}, nil)
  end

  def hangup(plugin_pid) do
    Janus.Plugin.message(plugin_pid, %{request: "hangup"}, nil)
  end

  def answer(plugin_pid, jsep) do
    session_id = get_session_id(plugin_pid)
    room_id = ConCache.get(:app_cache, %{session_id: session_id, type: "room_id"})

    Janus.Plugin.message(plugin_pid, %{request: "start", room: room_id}, jsep)
    :ok
  end

  def trickle(plugin_pid, ice_candidate) do
    Janus.Plugin.trickle(plugin_pid, ice_candidate)
  end

  def handle_event(event, parent) do
    IO.inspect("AND THE EVENT IS": event)

    case event do
      {:event, pid, plugin_pid, data, nil} ->
        IO.puts("Data received #{inspect(pid)}")
        IO.inspect("data: #{inspect(data)}")

        session_id = get_session_id(pid)
        room_id = ConCache.get(:app_cache, %{session_id: session_id, type: "room_id"})

        room_name = Enum.join(["room:user:", room_id], "")

        case data do
          %{error: error} ->
            IO.puts(inspect(error))
            IO.puts(inspect(parent))

          %{videoroom: "slow_link"} ->
            IO.puts("SLOW LINK PROBLEM")
            IO.puts("Current bitrate #{data[:"current-bitrate"]}")

            if data[:"current-bitrate"] && data[:"current-bitrate"] != 64000 do
              IO.puts("Sending reduced bitrate")

              :timer.apply_after(30000, Janus.Plugin, :message, [
                plugin_pid,
                %{request: "configure", bitrate: 256_000}
              ])

              Janus.Plugin.message(plugin_pid, %{request: "configure", bitrate: 64000})
            end

          %{configured: status, room: room, videoroom: "event"} ->
            IO.puts("configured")
            IO.puts(status)

          %{room: room, started: status, videoroom: "event"} ->
            IO.puts("started")
            IO.puts(room)
            IO.puts(status)

          %{publishers: []} ->
            IO.puts("Got publishers empty")

          %{publishers: nil} ->
            IO.puts("Got publishers nil")

          %{publishers: publishers} ->
            IO.puts("Got publishers")

            for publisher <- publishers do
              publisher_id = publisher[:id]
              display = publisher[:display]

              ConCache.put(:app_cache, publisher_id, display)

              IO.puts("Publisher id is #{inspect(publisher_id)}")

              {:ok, handle} =
                pid
                |> Janus.Session.attach_plugin("janus.plugin.videoroom")

              Janus.Plugin.add_handler(handle, RoomCall, nil)

              if publisher_id do
                Janus.Plugin.message(handle, %{
                  feed: publisher_id,
                  ptype: "listener",
                  request: "join",
                  room: room_id
                })
              end
            end

          %{leaving: []} ->
            IO.puts("Got leaving empty")

          %{leaving: nil} ->
            IO.puts("Got leaving nil")

          %{leaving: leaving} ->
            IO.puts("Got some data in leaving")
            IO.puts(inspect(leaving))

            remote_handle_id = ConCache.get(:handle_cache, plugin_pid)

            IO.puts("Got leaving event")
            IO.inspect(leaving)

            room_name = "room:videoroom"

            JanusPhoenixWebrtcDemoWeb.Endpoint.broadcast(room_name, "events", %{
              janus: :event,
              type: :leaving,
              remote_handle_id: remote_handle_id,
              leaving: leaving
            })

          %{unpublished: []} ->
            IO.puts("Got leaving empty")

          %{unpublished: nil} ->
            IO.puts("Got leaving nil")

          %{unpublished: unpublished} ->
            IO.puts("Got unpublished event")
            IO.inspect(unpublished)

            remote_handle_id = ConCache.get(:handle_cache, plugin_pid)

            room_name = "room:videoroom"

            JanusPhoenixWebrtcDemoWeb.Endpoint.broadcast(room_name, "events", %{
              janus: :event,
              type: :leaving,
              remote_handle_id: remote_handle_id,
              leaving: unpublished
            })
        end

      {:event, pid, plugin_pid, data, jsep} ->
        IO.puts("JSEP 1111 received: #{inspect(pid)}")
        IO.puts("data #{inspect(data)}")

        remote_handle_id = random_string(10)
        ConCache.put(:handle_cache, remote_handle_id, plugin_pid)
        ConCache.put(:handle_cache, plugin_pid, remote_handle_id)

        case data do
          %{id: publisher_id, videoroom: "attached"} ->
            IO.puts("GOT attached event")

            user_id = ConCache.get(:app_cache, pid)
            display = ConCache.get(:app_cache, publisher_id)
            room_name = Enum.join(["room:user:", user_id], "")

            IO.puts("Got some data here")
            IO.inspect(room_name)

            JanusPhoenixWebrtcDemoWeb.Endpoint.broadcast(room_name, "data", %{
              jsep: jsep,
              remote_handle_id: remote_handle_id,
              publisher_id: publisher_id,
              display: display
            })

          %{configured: "ok", room: videoroom, videoroom: "event"} ->
            IO.puts("GOT configured ok event")

            user_id = ConCache.get(:app_cache, pid)

            room_name = Enum.join(["room:user:", user_id], "")

            JanusPhoenixWebrtcDemoWeb.Endpoint.broadcast(room_name, "data", %{jsep: jsep})

          _ ->
            IO.puts("FATAL")
            IO.puts(inspect(data))
        end

      {:media, pid, plugin_pid, type, receiving} ->
        IO.puts("media receiving #{receiving} #{inspect(pid)}")

        if receiving == false and type == "video" do
          Janus.Session.destroy(pid)
          session_server = ConCache.get(:pid_cache, pid)
          Process.exit(session_server, :kill)
        end

      {:slowlink, pid, plugin_pid, uplink, nacks} ->
        IO.puts("slowlink #{uplink} NACKS #{nacks} #{inspect(pid)}")

      {:webrtcup, pid, plugin_pid} ->
        IO.puts("WebRTC UP #{inspect(pid)}")

      {:hangup, pid, plugin_pid, reason} ->
        IO.puts("Hangup #{inspect(pid)}")
        IO.puts("Reason: #{reason}")

      _ ->
        IO.puts("VideoroomCall call event occurred")
        IO.puts(inspect(event))
    end

    {:ok, parent}
  end

  defp random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end

  defp get_session_id(pid) do
    session_info = Agent.get(pid, & &1)
    Enum.at(String.split(session_info.base_url, "/"), 4)
  end

  defp get_plugin_id(pid) do
    session_info = Agent.get(pid, & &1)
    Enum.at(String.split(session_info.base_url, "/"), 5)
  end
end
