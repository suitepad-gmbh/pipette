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
    establish(stages, pattern)

    state = %{
      pattern: pattern,
      stages: stages
    }
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
    pids = Map.take(stages, block_ids)
           |> Map.values()
    {:reply, pids, state}
  end

  def start_blocks(%Pattern{blocks: blocks}) do
    Enum.reduce(blocks, %{}, fn {block_id, block}, acc ->
      {:ok, pid} = block.__struct__.start_link(block)
      Process.link(pid)
      Map.put(acc, block_id, pid)
    end)
  end

  def establish(stages, %Pattern{subscriptions: subscriptions}) do
    for subscription <- subscriptions do
      subscribe(stages, subscription)
    end
  end

  def subscribe(stages, {from, to}) when is_atom(to) do
    subscribe(stages, {from, {to, :ok}})
  end

  def subscribe(stages, {from, {to, route}}) do
    case {stages[from], stages[to]} do
      {nil, nil} ->
        Logger.error("'#{from}' and '#{to}' of subscription #{from} -> {#{to}, #{route}} are not defined")
      {nil, _} ->
        Logger.error("'#{from}' of subscription #{from} -> {#{to}, #{route}} is not defined")
      {_, nil} ->
        Logger.error("'#{to}' of subscription #{from} -> {#{to}, #{route}} is not defined")
      {from_stage, to_stage} ->
        {:ok, _ref} = GenStage.sync_subscribe(from_stage,
                                              to: to_stage,
                                              selector: &(&1.route == route),
                                              max_demand: 1)
    end
  end

end
