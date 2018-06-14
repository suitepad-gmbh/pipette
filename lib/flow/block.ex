defmodule Flow.Block do

  require Logger

  defstruct id: nil,
            fun: nil,
            module: nil,
            function: :call,
            stream: nil,
            args: nil

  alias Flow.Block
  alias Flow.IP
  use Flow.Stage, stage_type: :producer_consumer

  def handle_events([%IP{} = ip], _from, block) do
    new_ip = process_ip(ip, block)
    {:noreply, [new_ip], block}
  end

  def handle_cast(%IP{} = ip, block) do
    new_ip = process_ip(ip, block)
    {:noreply, [new_ip], block}
  end

  def process_ip(%IP{} = ip, block) do
    resp = perform(block, ip)
    IP.update(ip, resp)
  rescue
    error ->
      message = Exception.message(error)
      Logger.debug("error in #{inspect block}: #{message}")
      wrapped = %{
        error: error,
        message: message,
        block: block
      }
      %IP{ip | route: :error}
      |> IP.set_context(:error, wrapped)
  end

  def perform(%Block{fun: fun} = block, %IP{value: value}) when is_function(fun, 2) do
    fun.(value, block.args)
  end

  def perform(%Block{fun: fun}, %IP{value: value}) when is_function(fun, 1) do
    fun.(value)
  end

  def perform(%Block{module: module, function: function, args: nil}, %IP{value: value})
      when is_atom(function) do
    apply(module, function, [value])
  end

  def perform(%Block{module: module, function: function, args: args}, %IP{value: value})
      when is_atom(function) do
    apply(module, function, [value, args])
  end
end

