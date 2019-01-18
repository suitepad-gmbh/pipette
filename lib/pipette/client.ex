defmodule Pipette.Client do
  @moduledoc """
  Implements basic protocols for a FBP application.

  The basic idea behind a client is, to provide standard calling patterns for recipes.
  A recipe with its stages is executed asynchronously. A client can be used to wait for return values
  by blocking the calling process.

  It is common to start a single recipe, that works on messages from multiple clients.

  ## Call-based

  This basic protocol lets you _push_ messages into the `:IN`-stage of a recipe and _pulls_ one message
  from the `:OUT`-stage.

  The call blocks the caller and client (not the recipe) for a configurable timeout (default `:infinity`).

  ## Push-based

  This allows to _push_ messages into a specific (default: `:IN`) stage. Once sent, it returns.

  Note: The stage must implement `GenStage.handle_cast/2` in order to receive messages from a client.

  ## Pull-based

  You can use this to _pull_ messages from a specified (default: `:OUT`) stage.

  It does so by creating demand for one message on the stage, and waits for a single message.
  """
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

  @doc """
  Starts a client and return its pid.
  """
  def start(controller, opts \\ []) do
    {:ok, pid} = start_link(controller, opts)
    pid
  end

  @doc """
  Starts a client.
  """
  def start_link(controller, opts \\ []) do
    GenServer.start_link(__MODULE__, controller, opts)
  end

  @doc false
  def init(controller) do
    {:ok, controller}
  end

  @spec call(pid, ip_or_value :: term | Pipette.IP.t(), timeout :: integer | :infinity) ::
          {route :: atom, value :: term}
  @doc """
  Call the recipe of this client on `:IN` and wait for one message on `:OUT`.
  """
  def call(pid, ip_or_value, timeout \\ :infinity)

  def call(pid, %IP{} = ip, timeout) do
    GenServer.call(pid, {:call, ip, timeout}, :infinity)
  rescue
    error ->
      {:error, error}
  end

  def call(pid, value, timeout) do
    call(pid, IP.new(value), timeout)
  end

  @spec call!(pid, ip_or_value :: term | Pipette.IP.t(), timeout :: integer | :infinity) :: term
  @doc """
  Call the recipe of this client on `:IN` and wait for one message on `:OUT`.

  The potential failures are either a timeout occurs or the stage returns a value routed
  to something else than `{:ok, value}`.

  Raises `Pipette.Client.Error` or `Pipette.Client.TimeoutError` in case of failure.
  """
  def call!(pid, ip_or_value, timeout \\ :infinity)

  def call!(pid, %IP{} = ip, timeout) do
    case GenServer.call(pid, {:call, ip, timeout}, :infinity) do
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

  def call!(pid, value, timeout) do
    call!(pid, IP.new(value), timeout)
  end

  @spec push(pid(), value :: term | Pipette.IP.t(), keyword) :: term
  @doc """
  Push a message onto a stage (default: `:IN`).
  """
  def push(pid, ip_or_value, opts \\ [])

  def push(pid, %IP{} = ip, opts) do
    GenServer.call(pid, {:push, ip, opts})
  end

  def push(pid, value, opts) do
    push(pid, IP.new(value), opts)
  end

  @spec pull(pid, stage :: atom, timeout :: integer | :infinity) :: {route :: atom, value :: term}
  @doc """
  Pull one message from a stage (default: `:OUT`).
  """
  def pull(pid, stage, timeout \\ :infinity) do
    GenServer.call(pid, {:pull, stage}, timeout)
  end

  @doc false
  def handle_call({:push, %IP{} = ip, opts}, _from, controller) do
    stage = opts[:to] || :IN
    producer = Controller.get_stage_pid(controller, stage)

    GenStage.cast(producer, ip)
    {:reply, :ok, controller}
  end

  @doc false
  def handle_call({:pull, stage}, _from, controller) do
    pid = Controller.get_stage_pid(controller, stage)

    task =
      Task.async(fn ->
        GenStage.stream([{pid, max_demand: 1}])
        |> Stream.take(1)
        |> Enum.into([])
        |> List.first()
      end)

    %Pipette.IP{value: value} = Task.await(task, :infinity)
    {:reply, value, controller}
  end

  @doc false
  def handle_call({:call, %IP{} = ip, timeout}, _from, controller) do
    [producer, consumer] = Controller.get_stage_pids(controller, [:IN, :OUT])

    task =
      Task.async(fn ->
        ip = IP.set(ip, :reply_to, self())
        monitor = Process.monitor(consumer)
        GenStage.cast(producer, ip)
        await_response(ip.ref, monitor, timeout)
      end)

    {:reply, Task.await(task, :infinity), controller}
  end

  defp await_response(ref, monitor, timeout) do
    receive do
      # TODO: write tests
      %IP{route: route, value: value, ref: ^ref} ->
        Process.demonitor(monitor)
        {route, value}

      {:DOWN, ^monitor, _, _, _reason} ->
        {:error, %Error{message: "consumer went down while waiting for return on OUT"}}

      msg ->
        Logger.warn("unexpected message on Client.await_response/3: #{inspect(msg)}")
        await_response(ref, monitor, timeout)
    after
      timeout ->
        Process.demonitor(monitor)
        {:error, %TimeoutError{message: "timeout waiting for return on OUT"}}
    end
  end

  @doc false
  def handle_info(msg, controller) do
    Logger.info("#{__MODULE__} received an unexpected message: #{inspect(msg)}")
    {:noreply, controller}
  end
end
