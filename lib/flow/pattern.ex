defmodule Flow.Pattern do

  alias Flow.Pattern
  alias Flow.Block

  defstruct blocks: [],
    connections: [],
    instances: nil,
    subscriptions: nil,
    supervisor_pid: nil

  def start(pattern) do
    {:ok, supervisor_pid} = DynamicSupervisor.start_link(strategy: :one_for_one)

    instances = Enum.reduce(pattern.blocks, %{}, fn block, acc ->
      block = %{block | id: block.id || System.unique_integer()}
      {:ok, pid} = DynamicSupervisor.start_child(supervisor_pid, Block.child_spec(block))
      Map.put(acc, block.id, pid)
    end)

    %Pattern{pattern |
      supervisor_pid: supervisor_pid,
      instances: instances
    }
  end

  def connect(%Pattern{instances: instances} = pattern) do
    subscriptions = Enum.reduce(pattern.connections, %{}, fn {from, to}, acc ->
      {:ok, subscription} = GenStage.sync_subscribe(instances[from], to: instances[to], max_demand: 1)
      list = Map.get(acc, from, [])
      Map.put(acc, from, [{to, subscription} | list])
    end)

    %Pattern{pattern |
      subscriptions: subscriptions
    }
  end

  def outlet(%Pattern{instances: instances}, id) do
    Map.fetch(instances, id)
  end

end

