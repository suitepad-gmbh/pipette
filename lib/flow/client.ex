defmodule Flow.Client do
  use GenServer

  alias Flow.Pattern.Controller

  def start_link(pid_or_name, opts \\ []) do
    GenServer.start_link(__MODULE__, pid_or_name, opts)
  end

  def init(pid_or_name) do
    {:ok, pid_or_name}
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

  def handle_call({:push, value}, _from, pid_or_name) do
    producer = Controller.get_stage(pid_or_name, :IN)
    ip = %Flow.IP{value: value}
    GenStage.cast(producer, ip)
    {:reply, :ok, pid_or_name}
  end

  def handle_call({:pull, stage}, _from, pid_or_name) do
    pid = Controller.get_stage(pid_or_name, stage)
    task = Task.async(fn ->
      GenStage.stream([{pid, max_demand: 1}])
      |> Stream.take(1)
      |> Enum.into([])
      |> List.first
    end)
    %Flow.IP{value: value} = Task.await(task, :infinity)
    {:reply, value, pid_or_name}
  end

  def handle_call(value, _from, pid_or_name) do
    [producer, consumer] = Controller.get_stages(pid_or_name, [:IN, :OUT])
    reply_to = self()
    ip = Flow.IP.new(value, reply_to: reply_to)
    monitor = Process.monitor(consumer)
    GenStage.cast(producer, ip)
    value = await_response(reply_to, monitor)
    {:reply, value, pid_or_name}
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

