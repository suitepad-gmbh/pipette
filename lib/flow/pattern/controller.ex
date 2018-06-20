defmodule Flow.Pattern.Controller do
  use GenServer

  require Logger

  alias Flow.Pattern

  def child_spec(pattern) do
    %{
      id: pattern.id,
      start: {__MODULE__, :start_link, [pattern, [name: pattern.id]]}
    }
  end

  def start_link(pattern, opts \\ []) do
    opts = Keyword.merge([name: pattern.id], opts)
    GenServer.start_link(__MODULE__, pattern, opts)
  end

  def init(pattern) do
    stages = start_blocks(pattern)

    state = %{
      pattern: pattern,
      stages: stages
    }

    establish(state)
    {:ok, state}
  end

  def get_stage(pid, block_id) do
    [stage] = get_stages(pid, [block_id])
    stage
  end

  def get_stages(pid, block_ids) do
    GenServer.call(pid, {:get_stages, block_ids})
  end

  def handle_call({:get_stages, block_ids}, _from, %{stages: stages} = state) do
    pids =
      Map.take(stages, block_ids)
      |> Map.values()

    {:reply, pids, state}
  end

  def handle_call({:get_block, stage_pid}, _from, %{stages: stages, pattern: pattern} = state) do
    case Enum.find(stages, fn {key, value} -> value == stage_pid end) do
      {block_id, _} ->
        block = Map.get(pattern.blocks, block_id)
        {:reply, {block_id, block}, state}

      _ ->
        {:reply, nil, state}
    end
  end

  defp start_blocks(%Pattern{blocks: blocks}) do
    Enum.reduce(blocks, %{}, fn {block_id, block}, acc ->
      {:ok, pid} = block.__struct__.start_link(block)
      Process.link(pid)
      Map.put(acc, block_id, pid)
    end)
  end

  defp establish(%{pattern: %Pattern{subscriptions: subscriptions}} = state) do
    for subscription <- subscriptions do
      subscribe(state, subscription)
    end
  end

  defp subscribe(state, {from, to}) when is_atom(to) do
    subscribe(state, {from, {to, :ok}})
  end

  defp subscribe(%{stages: stages, pattern: %Pattern{blocks: blocks}}, {from, {:*, route}}) do
    from_stage = stages[from]

    for {stage_name, to_stage} when stage_name != from <- stages do
      module = blocks[stage_name].__struct__

      case module.stage_type() do
        stage_type when stage_type in [:producer, :producer_consumer] ->
          subscribe_to({from, from_stage}, {stage_name, to_stage}, route)

        _ ->
          nil
      end
    end
  end

  defp subscribe(%{stages: stages}, {from, {to, route}}) do
    subscribe_to({from, stages[from]}, {to, stages[to]}, route)
  end

  defp subscribe_to({from, nil}, {to, nil}, route) do
    Logger.error(
      "'#{from}' and '#{to}' of subscription #{from} -> {#{to}, #{route}} are not defined"
    )
  end

  defp subscribe_to({from, nil}, {to, _pid}, route) do
    Logger.error("'#{from}' of subscription #{from} -> {#{to}, #{route}} is not defined")
  end

  defp subscribe_to({from, _pid}, {to, nil}, route) do
    Logger.error("'#{to}' of subscription #{from} -> {#{to}, #{route}} is not defined")
  end

  defp subscribe_to({_from, from_stage}, {_to, to_stage}, route)
       when is_pid(from_stage) and is_pid(to_stage) do
    {:ok, _ref} =
      GenStage.sync_subscribe(
        from_stage,
        to: to_stage,
        selector: &(&1.route == route || route == :*),
        max_demand: 1
      )
  end
end
