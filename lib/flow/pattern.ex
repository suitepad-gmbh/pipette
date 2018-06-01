defmodule Flow.Pattern do

  alias Flow.Pattern
  alias Flow.Block

  defstruct blocks: %{},
    subscriptions: [],
    stages: nil,
    subscription_references: %{},
    supervisor_pid: nil

  def new(%{blocks: blocks, subscriptions: subscriptions}) do
    blocks = blocks
             |> Map.put(:IN, blocks[:IN] || %Block.PushProducer{})
             |> Map.put(:OUT, blocks[:OUT] || %Block.Consumer{})

    %Pattern{
      blocks: blocks,
      subscriptions: subscriptions
    }
  end

  def start(pattern) do
    {:ok, supervisor_pid} = DynamicSupervisor.start_link(strategy: :one_for_one)

    stages = Enum.reduce(pattern.blocks, %{}, fn {block_id, block}, acc ->
      block_spec = block.__struct__.child_spec(block)
      {:ok, pid} = DynamicSupervisor.start_child(supervisor_pid, block_spec)
      Map.put(acc, block_id, pid)
    end)

    %Pattern{pattern |
      supervisor_pid: supervisor_pid,
      stages: stages
    } |> establish
  end

  def get_stage(%Pattern{stages: stages}, id) do
    Map.fetch(stages, id)
  end

  def establish(pattern) do
    Enum.reduce(pattern.subscriptions, pattern, &(connect(&2, &1)))
  end

  def connect(%Pattern{subscription_references: refs} = pattern, {from, {to, route}}) do
    {:ok, ref} = subscribe(pattern, {from, {to, route}})

    list = [{from, {to, route}, ref} | Map.get(refs, from, [])]
    %Pattern{pattern | subscription_references: Map.put(refs, from, list)}
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

