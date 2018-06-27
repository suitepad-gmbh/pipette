defmodule Pipette.Handler do
  alias Pipette.IP

  @type return_t :: any | {atom, any} | IP.t()
  @callback call() :: return_t
  @callback call(value :: any) :: return_t
  @callback call(value :: any, args :: list(any)) :: return_t
  @callback call(value :: any, args :: list(any), ip :: IP.t()) :: return_t
  @optional_callbacks call: 0, call: 1, call: 2, call: 3

  def handle(handler, %IP{ref: ref} = ip) do
    case perform(handler, ip) do
      %IP{ref: ^ref} = ip -> ip
      %IP{} -> raise Pipette.Error.InvalidIP, "IP.ref mismatch"
      value -> IP.update(ip, value)
    end
  end

  def perform(fun, %IP{} = ip) when is_function(fun) do
    perform({fun, []}, ip)
  end

  def perform({fun, args}, %IP{}) when is_function(fun, 0) and is_list(args) do
    fun.()
  end

  def perform({fun, args}, %IP{value: value}) when is_function(fun, 1) and is_list(args) do
    fun.(value)
  end

  def perform({fun, args}, %IP{value: value}) when is_function(fun, 2) and is_list(args) do
    fun.(value, args)
  end

  def perform({fun, args}, %IP{value: value} = ip) when is_function(fun, 3) and is_list(args) do
    fun.(value, args, ip)
  end

  def perform(module, %IP{} = ip) when is_atom(module) do
    perform({module, :call, []}, ip)
  end

  def perform({module, args}, %IP{} = ip) when is_atom(module) and is_list(args) do
    perform({module, :call, args}, ip)
  end

  def perform({module, function_name}, %IP{} = ip)
      when is_atom(module) and is_atom(function_name) do
    perform({module, function_name, []}, ip)
  end

  def perform({module, function_name, args}, %IP{value: value} = ip)
      when is_atom(module) and is_atom(function_name) do
    cond do
      function_exported?(module, function_name, 3) ->
        apply(module, function_name, [value, args, ip])

      function_exported?(module, function_name, 2) ->
        apply(module, function_name, [value, args])

      function_exported?(module, function_name, 1) ->
        apply(module, function_name, [value])

      function_exported?(module, function_name, 0) ->
        apply(module, function_name, [])
    end
  end
end
