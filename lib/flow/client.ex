defmodule Flow.Client do
  use GenServer

  def start_link(pattern, opts \\ []) do
    GenServer.start_link(__MODULE__, pattern, opts)
  end

  def init(pattern) do
    {:ok, pattern}
  end

  def call(pid, value, timeout \\ :infinity) do
    GenServer.call(pid, value, timeout)
  end

  def push(pid, value) do
    GenServer.call(pid, {:push, value})
  end

  def pull(pid, stage) do
    GenServer.call(pid, {:pull, stage}, :infinity)
  end

  def handle_call({:push, value}, _from, %Flow.Pattern{stages: %{IN: producer}} = pattern) do
    ip = %Flow.IP{value: value}
    GenStage.cast(producer, ip)
    {:reply, :ok, pattern}
  end

  def handle_call({:pull, stage}, _from, %Flow.Pattern{stages: stages} = pattern) do
    pid = Map.get(stages, stage)
    task = Task.async(fn ->
      GenStage.stream([{pid, max_demand: 1}])
      |> Stream.take(1)
      |> Enum.into([])
      |> List.first
    end)
    %Flow.IP{value: value} = Task.await(task, :infinity)
    {:reply, value, pattern}
  end

  def handle_call(value, _from, %Flow.Pattern{stages: %{IN: producer, OUT: consumer}} = pattern) do
    reply_to = self()
    ip = Flow.IP.new(value, reply_to: reply_to)
    monitor = Process.monitor(consumer)
    GenStage.cast(producer, ip)
    value = await_response(reply_to, monitor)
    {:reply, value, pattern}
  end

  def await_response(pid, monitor) do
    receive do
      %Flow.IP{value: value, reply_to: ^pid} ->
        Process.demonitor(monitor)
        value
      {:DOWN, ^monitor, _, _, _reason} ->
        # TODO: Error, consumer went down
        nil
      _ ->
        await_response(pid, monitor)
    end
  end

end

