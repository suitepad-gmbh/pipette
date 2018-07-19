defmodule Pipette.Test.Controller do
  @moduledoc false
  use GenServer

  alias Pipette.Client
  alias Pipette.IP
  alias Pipette.Recipe

  def child_spec(recipe_and_args, opts \\ []) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [recipe_and_args, opts]}}
  end

  def start_link(recipe_and_args, opts \\ []) do
    GenServer.start_link(__MODULE__, recipe_and_args, opts)
  end

  def start(recipe, args \\ [], opts \\ []) do
    {:ok, pid} = start_link({recipe, args}, opts)
    pid
  end

  def init({recipe, args}) do
    controller =
      recipe
      |> create_test_recipe(args)
      |> Recipe.start_controller()

    client = Client.start(controller)

    state = %{
      controller: controller,
      client: client
    }

    {:ok, state}
  end

  def handle_call(:get_controller, _, %{controller: controller} = state) do
    {:reply, controller, state}
  end

  def handle_call({:push, value, inlet}, _from, %{client: client} = state) do
    Client.push(client, value, to: inlet)
    {:reply, :ok, state}
  end

  def handle_call(:events, _from, %{controller: controller} = state) do
    stage_pid = Pipette.Controller.get_stage_pid(controller, :__TEST_CONSUMER__)
    events = GenServer.call(stage_pid, :events)

    {:reply, events, state}
  end

  def events(pid) do
    GenServer.call(pid, :events)
  end

  @doc """
  Requests the result for the given stage. If there is no current result, it
  waits for it.
  """
  def await(pid, stage_id \\ :OUT, opts \\ []) do
    controller = GenServer.call(pid, :get_controller)
    stage_pid = Pipette.Controller.get_stage_pid(controller, :__TEST_CONSUMER__)

    Task.async(fn ->
      GenServer.cast(stage_pid, {:fetch, stage_id, self()})
      await_fetch_response()
    end)
    |> Task.await(opts[:timeout] || 5000)
  end

  def push(pid, value, inlet \\ :IN) do
    GenServer.call(pid, {:push, value, inlet})
    pid
  end

  defp create_test_recipe(recipe, args) do
    stages = create_test_stage_map(recipe.stages, args)
    subscriptions = [{:__TEST_CONSUMER__, {:*, :*}} | recipe.subscriptions]

    %Recipe{recipe | id: nil, stages: stages, subscriptions: subscriptions}
  end

  defp create_test_stage_map(stages, args) do
    stages
    |> Enum.reduce(%{}, fn {key, stage}, acc ->
      new_stage =
        case {stage.__struct__.stage_type, args[:keep_producer]} do
          {:consumer, _} -> %Pipette.Stage.Passthrough{id: key}
          {:producer, true} -> stage
          {:producer, _} -> %Pipette.Stage.PushProducer{id: key}
          _ -> stage
        end

      Map.put(acc, key, new_stage)
    end)
    |> Map.put(:__TEST_CONSUMER__, %Pipette.Test.Consumer{test_controller_pid: self()})
  end

  defp await_fetch_response() do
    receive do
      {:fetch_response, %IP{} = ip} ->
        ip

      _ ->
        await_fetch_response()
    end
  end
end
