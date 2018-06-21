defmodule Pipette.Test.Controller do
  use GenServer

  alias Pipette.Client
  alias Pipette.IP
  alias Pipette.Recipe

  def child_spec(recipe, opts \\ []) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [recipe, opts]}}
  end

  def start_link(recipe, opts \\ []) do
    GenServer.start_link(__MODULE__, recipe, opts)
  end

  def start(recipe, opts \\ []) do
    {:ok, pid} = start_link(recipe, opts)
    pid
  end

  def init(recipe) do
    controller =
      recipe
      |> create_test_recipe
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

  def handle_call({:push, value}, _from, %{client: client} = state) do
    Client.push(client, value)
    {:reply, :ok, state}
  end

  def handle_call(:events, _from, %{controller: controller} = state) do
    stage_pid = Pipette.Controller.get_stage_pid(controller, :__TEST_CONSUMER__)
    events = GenServer.call(stage_pid, :events)

    {:reply, events, state}
  end

  @doc """
  Returns the recorded events
  """
  def events(pid) do
    GenServer.call(pid, :events)
  end

  @doc """
  Requests the result for the given stage. If there is no current result, it
  waits for it.
  """
  def await(pid, stage_id \\ :OUT) do
    controller = GenServer.call(pid, :get_controller)
    stage_pid = Pipette.Controller.get_stage_pid(controller, :__TEST_CONSUMER__)

    Task.async(fn ->
      GenServer.cast(stage_pid, {:fetch, stage_id, self()})
      await_fetch_response()
    end)
    |> Task.await()
  end

  @doc """
  Pushes the given value onto the recipe
  """
  def push(pid, value) do
    GenServer.call(pid, {:push, value})
    pid
  end

  defp create_test_recipe(recipe) do
    stages = create_test_stage_map(recipe.stages)
    subscriptions = [{:__TEST_CONSUMER__, {:*, :*}} | recipe.subscriptions]

    %Recipe{recipe | id: nil, stages: stages, subscriptions: subscriptions}
  end

  defp create_test_stage_map(stages) do
    stages
    |> Enum.reduce(%{}, fn {key, stage}, acc ->
      new_stage =
        case stage.__struct__.stage_type do
          :consumer -> %Pipette.Stage.Passthrough{id: key}
          :producer -> %Pipette.Stage.PushProducer{id: key}
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
