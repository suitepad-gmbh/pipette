defmodule Flow.Stage do

  alias Flow.IP
  alias Flow.Stage

  defstruct producers: [],
    fun: nil,
    module: nil,
    function: nil,
    op: :flow

  def call(stage, ip) do
    perform(stage, ip)
  rescue
    error ->
      wrapped = %{
        error: error,
        message: Exception.message(error),
        stage: stage,
        args: [ip.value]
      }
      %IP{ip | is_error: true, value: wrapped}
  end

  def perform(%Stage{fun: fun} = stage, %IP{value: value} = ip) when is_function(fun) do
    new_value = fun.(value)
    update_ip(stage, ip, new_value)
  end

  def perform(%Stage{module: module, function: atom} = stage, %IP{value: value} = ip) do
    new_value = apply(module, atom, [value])
    update_ip(stage, ip, new_value)
  end

  def update_ip(%Stage{op: :flow}, ip, new_value), do: %IP{ip | value: new_value}
  def update_ip(%Stage{op: {:put, key}}, ip, new_value) do
    %IP{ip | value: Map.put(ip.value, key, new_value)}
  end
end

