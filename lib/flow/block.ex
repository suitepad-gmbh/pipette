defmodule Flow.Block do
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
    resp = perform(block, ip)
    new_ip = IP.update(ip, resp)
    {:noreply, [new_ip], block}
  rescue
    error ->
      wrapped = %{
        error: error,
        message: Exception.message(error),
        block: block
      }

      new_ip =
        %IP{ip | route: :error}
        |> IP.set_context(:error, wrapped)

      {:noreply, [new_ip], block}
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
