defmodule SessionCall do
  use GenEvent

  def handle_event(event, parent) do
    case event do
      {:keepalive, pid} ->
        IO.puts("KEEP ALIVE #{inspect(pid)}")

      _ ->
        IO.puts("FATAL:: Not into any category")
        IO.puts(inspect(event))
    end

    {:ok, parent}
  end

  def destroy(pid) do
    Janus.Session.destroy(pid)
  end
end
