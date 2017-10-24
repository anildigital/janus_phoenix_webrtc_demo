defmodule Janus.Supervisor do
  use Supervisor

  @name Janus.Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    children = [
      Janus.Session.GenServer
    ]

    Supervisor.init(children, strategy: :simple_one_for_one)
  end
end
