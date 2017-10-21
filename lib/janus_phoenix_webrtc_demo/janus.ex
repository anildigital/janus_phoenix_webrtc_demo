defmodule JanusPhoenixWebrtcDemo.Janus do
  def create_janus_videoroom(room_name) do
    janus_url = Application.get_env(:janus_phoenix_webrtc_demo, :janus_url)
    {:ok, session} = Janus.Session.start(janus_url)

    {:ok, handle} =
      session
      |> Janus.Session.attach_plugin("janus.plugin.videoroom")

    # if not call create room
    {:ok, response} =
      Janus.Plugin.message(handle, %{
        request: "create",
        description: room_name,
        bitrate: 2_000_000,
        publishers: 20,
        permanent: true
      })

    room_id = response.plugindata.data.room

    room_id
  end
end
