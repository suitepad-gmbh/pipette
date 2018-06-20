defmodule Flow.Test.Controller do
  use GenServer

  alias Flow.Client
  alias Flow.IP
  alias Flow.Pattern

  def child_spec(pattern, opts \\ []) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [pattern, opts]}}
  end

  def start_link(pattern, opts \\ []) do
    GenServer.start_link(__MODULE__, pattern, opts)
  end

  def start(pattern, opts \\ []) do
    {:ok, pid} = start_link(pattern, opts)
    pid
  end

  def init(pattern) do
    controller =
      pattern
      |> create_test_pattern
      |> Pattern.start_controller()

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
    stage_pid = Pattern.Controller.get_stage(controller, :__TEST_CONSUMER__)
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
  Requests the result for the given block. If there is no current result, it
  waits for it.
  """
  def await(pid, block_id \\ :OUT) do
    controller = GenServer.call(pid, :get_controller)
    stage_pid = Pattern.Controller.get_stage(controller, :__TEST_CONSUMER__)

    Task.async(fn ->
      GenServer.cast(stage_pid, {:fetch, block_id, self()})
      await_fetch_response()
    end)
    |> Task.await()
  end

  @doc """
  Pushes the given value onto the pattern
  """
  def push(pid, value) do
    GenServer.call(pid, {:push, value})
    pid
  end

  defp create_test_pattern(pattern) do
    blocks = create_test_block_map(pattern.blocks)
    subscriptions = [{:__TEST_CONSUMER__, {:*, :*}} | pattern.subscriptions]

    %Pattern{pattern | id: nil, blocks: blocks, subscriptions: subscriptions}
  end

  defp create_test_block_map(blocks) do
    blocks
    |> Enum.reduce(%{}, fn {key, block}, acc ->
      new_block =
        case block.__struct__.stage_type do
          :consumer -> %Flow.Block.Passthrough{id: key}
          :producer -> %Flow.Block.PushProducer{id: key}
          _ -> block
        end

      Map.put(acc, key, new_block)
    end)
    |> Map.put(:__TEST_CONSUMER__, %Flow.Test.Consumer{test_controller_pid: self()})
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
