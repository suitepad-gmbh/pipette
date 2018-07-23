defmodule Pipette.Controller do
  @moduledoc """
  This module is the process that binds all stages and subscriptions of a `Pipette.Recipe`.
  """

  use GenServer

  require Logger

  alias Pipette.Recipe

  @start_stage Application.get_env(:pipette, :start_stage, {__MODULE__, :start_stage, []})

  @doc false
  def child_spec(recipe) do
    %{
      id: recipe.id,
      start: {__MODULE__, :start_link, [recipe, [name: recipe.id]]}
    }
  end

  @doc """
  Starts a given recipe, its `GenStage`s and creates all subscriptions between them.
  """
  def start_link(recipe, opts \\ []) do
    opts = Keyword.merge([name: recipe.id], opts)
    GenServer.start_link(__MODULE__, recipe, opts)
  end

  @doc false
  def init(recipe) do
    stage_pids = start_stages(recipe)

    state = %{
      recipe: recipe,
      stage_pids: stage_pids
    }

    establish(state)
    {:ok, state}
  end

  @doc """
  Returns the pid of a `GenStage` by its label.
  """
  def get_stage_pid(pid, stage_id) do
    [stage_pid] = get_stage_pids(pid, [stage_id])
    stage_pid
  end

  @doc """
  Returns all `GenStage` pids from a list of labels.
  """
  def get_stage_pids(pid, stage_ids) do
    GenServer.call(pid, {:get_stage_pids, stage_ids})
  end

  @doc false
  def handle_call({:get_stage_pids, stage_ids}, _from, %{stage_pids: stage_pids} = state) do
    pids =
      Map.take(stage_pids, stage_ids)
      |> Map.values()

    {:reply, pids, state}
  end

  @doc false
  def handle_call(
        {:get_stage, stage_pid},
        _from,
        %{stage_pids: stage_pids, recipe: recipe} = state
      ) do
    case Enum.find(stage_pids, fn {_key, pid} -> pid == stage_pid end) do
      {stage_id, _} ->
        stage = Map.get(recipe.stages, stage_id)
        {:reply, {stage_id, stage}, state}

      _ ->
        {:reply, nil, state}
    end
  end

  defp start_stages(%Recipe{stages: stages}) do
    Enum.reduce(stages, %{}, fn {stage_id, stage}, acc ->
      {module, func, args} = @start_stage
      {:ok, pid} = apply(module, func, [stage, args])
      Process.link(pid)
      Map.put(acc, stage_id, pid)
    end)
  end

  def start_stage(%{__struct__: module} = stage, _args) when is_atom(module) do
    module.start_link(stage)
  end

  defp establish(%{recipe: %Recipe{subscriptions: subscriptions}} = state) do
    for subscription <- subscriptions do
      subscribe(state, subscription)
    end
  end

  defp subscribe(state, {from, to}) when is_atom(to) do
    subscribe(state, {from, {to, :ok}})
  end

  defp subscribe(
         %{stage_pids: stage_pids, recipe: %Recipe{stages: stages}},
         {from_id, {:*, route}}
       ) do
    from_pid = stage_pids[from_id]

    for {stage_id, to_pid} when stage_id != from_id <- stage_pids do
      module = stages[stage_id].__struct__

      case module.stage_type() do
        stage_type when stage_type in [:producer, :producer_consumer] ->
          subscribe_to({from_id, from_pid}, {stage_id, to_pid}, route)

        _ ->
          nil
      end
    end
  end

  defp subscribe(%{stage_pids: stage_pids}, {from, {to, route}}) do
    subscribe_to({from, stage_pids[from]}, {to, stage_pids[to]}, route)
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

  defp subscribe_to({_from, from_pid}, {_to, to_pid}, route)
       when is_pid(from_pid) and is_pid(to_pid) do
    {:ok, _ref} =
      GenStage.sync_subscribe(
        from_pid,
        to: to_pid,
        selector: &(&1.route == route || route == :*),
        max_demand: 1
      )
  end
end
