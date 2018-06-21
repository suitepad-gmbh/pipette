defmodule Pipette.Client do
  use GenServer

  require Logger

  defmodule TimeoutError do
    defexception [:message]
  end

  defmodule Error do
    defexception [:message, :error]
  end

  alias Pipette.Controller
  alias Pipette.IP

  def start(pid_or_name, opts \\ []) do
    {:ok, pid} = start_link(pid_or_name, opts)
    pid
  end

  def start_link(pid_or_name, opts \\ []) do
    GenServer.start_link(__MODULE__, pid_or_name, opts)
  end

  def init(pid_or_name) do
    {:ok, pid_or_name}
  end

  def call(pid, value, timeout \\ :infinity) do
    GenServer.call(pid, {:call, value, timeout}, :infinity)
  rescue
    error ->
      {:error, error}
  end

  def call!(pid, value, timeout \\ :infinity) do
    case GenServer.call(pid, {:call, value, timeout}, :infinity) do
      {:ok, value} ->
        value

      {:error, %TimeoutError{} = e} ->
        raise e

      {:error, %Error{} = e} ->
        raise e

      error ->
        raise Error,
          message: "unexpected response received",
          error: error
    end
  end

  def push(pid, value, opts \\ []) do
    GenServer.call(pid, {:push, value, opts})
  end

  def pull(pid, stage) do
    GenServer.call(pid, {:pull, stage}, :infinity)
  end

  def handle_call({:push, value, opts}, _from, pid_or_name) do
    stage = opts[:to] || :IN
    producer = Controller.get_stage_pid(pid_or_name, stage)
    ip = IP.new(value)

    GenStage.cast(producer, ip)
    {:reply, :ok, pid_or_name}
  end

  def handle_call({:pull, stage}, _from, pid_or_name) do
    pid = Controller.get_stage_pid(pid_or_name, stage)

    task =
      Task.async(fn ->
        GenStage.stream([{pid, max_demand: 1}])
        |> Stream.take(1)
        |> Enum.into([])
        |> List.first()
      end)

    %Pipette.IP{value: value} = Task.await(task, :infinity)
    {:reply, value, pid_or_name}
  end

  def handle_call({:call, value, timeout}, _from, pid_or_name) do
    [producer, consumer] = Controller.get_stage_pids(pid_or_name, [:IN, :OUT])

    task =
      Task.async(fn ->
        reply_to = self()
        ip = IP.new(value, reply_to: reply_to)
        monitor = Process.monitor(consumer)
        GenStage.cast(producer, ip)
        await_response(ip.ref, monitor, timeout)
      end)

    {:reply, Task.await(task), pid_or_name}
  end

  def await_response(ref, monitor, timeout) do
    receive do
      # TODO: write tests
      %IP{route: route, value: value, ref: ^ref} ->
        Process.demonitor(monitor)
        {route, value}

      {:DOWN, ^monitor, _, _, _reason} ->
        {:error, %Error{message: "consumer went down while waiting for return on OUT"}}

      msg ->
        Logger.warn("unexpected message on Client.await_response/3: #{inspect msg}")
        await_response(ref, monitor, timeout)
    after
      timeout ->
        Process.demonitor(monitor)
        {:error, %TimeoutError{message: "timeout waiting for return on OUT"}}
    end
  end

  def handle_info(msg, pid_or_name) do
    Logger.info("#{__MODULE__} received an unexpected message: #{inspect(msg)}")
    {:noreply, pid_or_name}
  end
end
