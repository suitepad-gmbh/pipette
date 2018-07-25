defmodule Pipette.Handler do
  @moduledoc """
  The type that declares a handler.

  There are two ways to specify a handler.

  An anonymous function with either arity-0/1/2/3

      fn -> "value" end
      fn value -> "return" end
      fn value, args -> "return" end
      fn value, args, %IP{} = ip -> "return" end

  A tuple specifying the module, function and optional keyword arguments

      Module
      {Module, [named: "arg"]}
      {Module, :function}
      {Module, :function, [named: "foo", arg: "bar"]}

  If you do not specify a function for the module, the module is expected to implement  one of `call/0/1/2/3`.

  Used in `Pipette.Stage`, `Pipette.Consumer`, etc. to declare the implementation of stages.

      defmodule FooToBarRecipe do
        use Pipette.Recipe

        @stage foo_to_bar: %Stage{
                 # this handler turns "foo" into "bar" and passes other values
                 handler: fn
                   "foo" -> "bar"
                   other -> other
                 end
               }
      end
  """

  alias Pipette.IP

  require Logger

  @type t ::
          fun()
          | module()
          | {module(), keyword()}
          | {module(), atom()}
          | {module(), atom(), keyword()}

  @typedoc """
  The expected return type from any handler call.
  """
  @type return_t :: any | {atom, any} | IP.t()

  @handler Application.get_env(:pipette, :handler, __MODULE__)

  @doc false
  def call(handler, ip) do
    @handler.handle(handler, ip)
  end

  @doc false
  def handle(handler, %IP{ref: ref} = ip) do
    case perform(handler, ip) do
      %IP{ref: ^ref} = ip -> ip
      %IP{} -> raise Pipette.Error.InvalidIP, "IP.ref mismatch"
      value -> IP.update(ip, value)
    end
  end

  @doc false
  def perform(fun, %IP{} = ip) when is_function(fun) do
    perform({fun, []}, ip)
  end

  @doc false
  def perform({fun, args}, %IP{}) when is_function(fun, 0) and is_list(args) do
    fun.()
  end

  @doc false
  def perform({fun, args}, %IP{value: value}) when is_function(fun, 1) and is_list(args) do
    fun.(value)
  end

  @doc false
  def perform({fun, args}, %IP{value: value}) when is_function(fun, 2) and is_list(args) do
    fun.(value, args)
  end

  @doc false
  def perform({fun, args}, %IP{value: value} = ip) when is_function(fun, 3) and is_list(args) do
    fun.(value, args, ip)
  end

  @doc false
  def perform(module, %IP{} = ip) when is_atom(module) do
    perform({module, :call, []}, ip)
  end

  @doc false
  def perform({module, args}, %IP{} = ip) when is_atom(module) and is_list(args) do
    perform({module, :call, args}, ip)
  end

  @doc false
  def perform({module, function_name}, %IP{} = ip)
      when is_atom(module) and is_atom(function_name) do
    perform({module, function_name, []}, ip)
  end

  @doc false
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

      true ->
        raise "Handler function not found (module: #{module}, function: #{function_name})"
    end
  end
end
