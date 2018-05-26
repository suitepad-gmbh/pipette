defmodule Flow.Pattern do

  alias Flow.Pattern
  alias Flow.Block

  defstruct blocks: [],
    connections: [],
    stages: nil,
    subscriptions: %{},
    supervisor_pid: nil

  def start(pattern) do
    {:ok, supervisor_pid} = DynamicSupervisor.start_link(strategy: :one_for_one)

    stages = Enum.reduce(pattern.blocks, %{}, fn block, acc ->
      block = %{block | id: block.id || System.unique_integer()}
      {:ok, pid} = DynamicSupervisor.start_child(supervisor_pid, Block.child_spec(block))
      Map.put(acc, block.id, pid)
    end)

    %Pattern{pattern |
      supervisor_pid: supervisor_pid,
      stages: stages
    }
  end

  def get_stage(%Pattern{stages: stages}, id) do
    Map.fetch(stages, id)
  end

  def establish(pattern) do
    Enum.reduce(pattern.connections, pattern, &(connect(&2, &1)))
  end

  def connect(%Pattern{subscriptions: subscriptions} = pattern, {from, {to, route}}) do
    {:ok, subscription} = subscribe(pattern, {from, {to, route}})

    list = [{from, {to, route}, subscription} | Map.get(subscriptions, from, [])]
    %Pattern{pattern | subscriptions: Map.put(subscriptions, from, list)}
  end

  def connect(pattern, {from, to}) when is_atom(to) do
    connect(pattern, {from, {to, :ok}})
  end

  def subscribe(%Pattern{stages: stages}, {from, {to, route}}) do
    GenStage.sync_subscribe(stages[from],
                            to: stages[to],
                            selector: &(&1.route == route),
                            max_demand: 1)
  end

  def subscribe(pattern, {from, to}) when is_atom(to) do
    subscribe(pattern, {from, {to, :ok}})
  end

end

