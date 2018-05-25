defmodule Flow.Block do

  defstruct type: :producer_consumer,
    id: nil,
    fun: nil,
    module: nil,
    function: nil,
    args: nil,
    inputs: [],
    outputs: []

  alias Flow.Block
  alias Flow.IP
  use GenStage

  def start_link(block, opts \\ []) do
    GenStage.start_link(__MODULE__, block, opts)
  end

  def init(block) do
    {block.type, block}
  end

  def handle_events([ip], _from, %Block{type: :producer_consumer} = block) do
    new_ip = perform(block, ip)
    {:noreply, [new_ip], block}
  rescue
    error ->
      wrapped = %{
        error: error,
        message: Exception.message(error),
        block: block
      }
      %IP{ip | is_error: true, error: wrapped}
  end

  def handle_events([ip], _from, %Block{type: :consumer} = block) do
    if is_pid(ip.reply_to) do
      send(ip.reply_to, ip)
    end
    {:noreply, [], block}
  end

  def handle_demand(demand, %Block{type: :producer} = block) when demand > 0 do
    ips = produce(block, demand)
    {:noreply, ips, block}
  end

  def perform(%Block{fun: fun} = block, %IP{value: value} = ip) when is_function(fun, 2) do
    new_value = fun.(value, block.args)
    %IP{ip | value: new_value}
  end

  def perform(%Block{fun: fun}, %IP{value: value} = ip) when is_function(fun, 1) do
    new_value = fun.(value)
    %IP{ip | value: new_value}
  end

  def perform(%Block{module: module} = block, %IP{value: value} = ip) do
    function = block.function || :call
    new_value = apply(module, function, [value, block.args])
    %IP{ip | value: new_value}
  end

  def produce(%Block{fun: fun} = block, demand) when is_function(fun, 2) do
    Enum.map(1..demand, &(%IP{value: fun.(&1, block.args)}))
  end

  def produce(%Block{fun: fun}, demand) when is_function(fun, 1) do
    Enum.map(1..demand, &(%IP{value: fun.(&1)}))
  end

  def produce(%Block{fun: fun}, demand) when is_function(fun, 0) do
    Enum.map(1..demand, fn _ -> %IP{value: fun.()} end)
  end

end

