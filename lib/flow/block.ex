defmodule Flow.Block do

  defstruct id: nil,
    fun: nil,
    module: nil,
    function: :call,
    stream: nil,
    args: nil

  alias Flow.Block
  alias Flow.IP
  use GenStage

  def start_link(block, opts \\ []) do
    GenStage.start_link(__MODULE__, block, opts)
  end

  def init(block) do
    dispatcher = {GenStage.BroadcastDispatcher, []}
    {:producer_consumer, block, dispatcher: dispatcher}
  end

  def handle_events([%IP{value: value} = ip], _from, block) do
    resp = perform(block, value)
    new_ip = IP.update(ip, resp)
    {:noreply, [new_ip], block}
  rescue
    error ->
      wrapped = %{
        error: error,
        message: Exception.message(error),
        block: block
      }
      new_ip = %IP{ip | route: :error}
               |> IP.set_context(:error, wrapped)
    {:noreply, [new_ip], block}
  end

  def perform(%Block{fun: fun} = block, value) when is_function(fun, 2) do
    fun.(value, block.args)
  end

  def perform(%Block{fun: fun}, value) when is_function(fun, 1) do
    fun.(value)
  end

  def perform(%Block{module: module, function: function, args: nil}, value)
  when is_atom(function)
  do
    apply(module, function, [value])
  end

  def perform(%Block{module: module, function: function, args: args}, value)
  when is_atom(function)
  do
    apply(module, function, [value, args])
  end

end

