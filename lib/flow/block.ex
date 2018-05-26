defmodule Flow.Block do

  defstruct type: :producer_consumer,
    id: nil,
    fun: nil,
    module: nil,
    function: nil,
    stream: nil,
    args: nil,
    inputs: [],
    outputs: []

  alias Flow.Block
  alias Flow.IP
  use GenStage

  def child_spec(%Block{type: :producer, stream: stream}) when not is_nil(stream) do
    arg = {stream, dispatcher: GenStage.BroadcastDispatcher}
    %{id: GenStage.Streamer, start: {GenStage, :start_link, [GenStage.Streamer, arg]}}
  end

  def child_spec(block) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [block]}}
  end

  def start_link(block, opts \\ []) do
    GenStage.start_link(__MODULE__, block, opts)
  end

  def init(block) do
    dispatcher = {GenStage.BroadcastDispatcher, []}
    {block.type, block, dispatcher: dispatcher}
  end

  def handle_events([ip], _from, %Block{type: :producer_consumer} = block) do
    new_ip = perform(block, ip) |> route_ip(ip)
    {:noreply, [new_ip], block}
  rescue
    error ->
      wrapped = %{
        error: error,
        message: Exception.message(error),
        block: block
      }
      new_ip = %IP{ip | route: :error, is_error: true, error: wrapped}
    {:noreply, [new_ip], block}
  end

  def handle_events([ip], _from, %Block{type: :consumer} = block) do
    if is_pid(ip.reply_to) do
      send(ip.reply_to, ip)
    end
    {:noreply, [], block}
  end

  def perform(%Block{fun: fun} = block, %IP{value: value}) when is_function(fun, 2) do
    fun.(value, block.args)
  end

  def perform(%Block{fun: fun}, %IP{value: value}) when is_function(fun, 1) do
    fun.(value)
  end

  def perform(%Block{module: module} = block, %IP{value: value} = ip) do
    function = block.function || :call
    apply(module, function, [value, block.args])
  end

  def handle_demand(demand, %Block{type: :producer} = block) when demand > 0 do
    ips = produce(block, demand)
    {:noreply, ips, block}
  end

  def produce(%Block{fun: fun, args: args}, demand) when is_function(fun, 1) do
    Enum.map(1..demand, fn _ ->
      fun.(args) |> route_ip()
    end)
  end

  def produce(%Block{fun: fun}, demand) when is_function(fun, 0) do
    Enum.map(1..demand, fn _ ->
      fun.() |> route_ip()
    end)
  end

  def route_ip(value, ip \\ %IP{})

  def route_ip({route, new_value}, ip) when is_atom(route) do
    %IP{ip | route: route, value: new_value}
  end

  def route_ip(new_value, ip) do
    %IP{ip | route: :ok, value: new_value}
  end

end

