defmodule Pipette.HandlerTest do
  use ExUnit.Case

  alias Pipette.IP
  alias Pipette.Handler

  defmodule TestModule0 do
    @behaviour Pipette.Handler

    def call(), do: "call/0"
    def run(), do: "run/0"
  end

  defmodule TestModule1 do
    @behaviour Pipette.Handler

    def call(value), do: "call/1 (#{value})"
    def run(value), do: "run/1 (#{value})"
  end

  defmodule TestModule2 do
    @behaviour Pipette.Handler

    def call(value, args), do: "call/2 (#{value}, #{inspect(args)})"
  end

  defmodule TestModule3 do
    @behaviour Pipette.Handler

    def call(value, args, %IP{}), do: "call/3 (#{value}, #{inspect(args)}, IP)"
    def run(value, args, %IP{}), do: "run/3 (#{value}, #{inspect(args)}, IP)"
  end

  defmodule TestModuleAmbigious do
    defdelegate call(value), to: TestModule1
    defdelegate call(value, args), to: TestModule2
  end

  setup do
    ip = IP.new("foo")
    {:ok, %{ip: ip}}
  end

  test "#handle updates the value of the given IP", %{ip: ip} do
    ip_ref = ip.ref

    assert %IP{route: :ok, value: "bar", ref: ^ip_ref} = Handler.handle(fn _ -> "bar" end, ip)
  end

  test "#handle update the route of the IP", %{ip: ip} do
    ip_ref = ip.ref

    assert %IP{route: :error, value: "bar", ref: ^ip_ref} =
             Handler.handle(fn _ -> {:error, "bar"} end, ip)
  end

  test "#handle returns a new IP", %{ip: ip} do
    new_ip = Handler.handle(fn _, _, ip -> IP.set_context(ip, :foo, :bar) end, ip)
    assert %IP{context: %{foo: :bar}} = new_ip
  end

  test "#handle raises an error if the new IP ref doesn't match", %{ip: %IP{} = ip} do
    assert_raise Pipette.Error.InvalidIP, "IP.ref mismatch", fn ->
      Handler.handle(fn _ -> IP.new("foo") end, ip)
    end
  end

  test "#perform handles a module without arguments", %{ip: ip} do
    assert "call/0" == Handler.perform(TestModule0, ip)
    assert "call/0" == Handler.perform({TestModule0, [1, 2, 3]}, ip)
  end

  test "#perform handles a module with a given function name without arguments", %{ip: ip} do
    assert "run/0" == Handler.perform({TestModule0, :run}, ip)
    assert "run/0" == Handler.perform({TestModule0, :run, [1, 2, 3]}, ip)
  end

  test "#perform handles a module", %{ip: ip} do
    assert "call/1 (foo)" == Handler.perform(TestModule1, ip)
    assert "call/1 (foo)" == Handler.perform({TestModule1, [1, 2, 3]}, ip)
  end

  test "#perform handle a module with static arguments", %{ip: ip} do
    assert "call/2 (foo, [1, 2, 3])" == Handler.perform({TestModule2, [1, 2, 3]}, ip)
    assert "call/2 (foo, [])" == Handler.perform(TestModule2, ip)
    assert "call/2 (foo, [])" == Handler.perform(TestModuleAmbigious, ip)
  end

  test "#perform handles a module with a given function name", %{ip: ip} do
    assert "run/1 (foo)" == Handler.perform({TestModule1, :run}, ip)
    assert "run/1 (foo)" == Handler.perform({TestModule1, :run, [1, 2, 3]}, ip)
  end

  test "#perform handles a module that implements 3-arity function", %{ip: ip} do
    assert "call/3 (foo, [], IP)" == Handler.perform(TestModule3, ip)
    assert "call/3 (foo, [1, 2, 3], IP)" == Handler.perform({TestModule3, [1, 2, 3]}, ip)
    assert "run/3 (foo, [], IP)" == Handler.perform({TestModule3, :run}, ip)
    assert "run/3 (foo, [1, 2, 3], IP)" == Handler.perform({TestModule3, :run, [1, 2, 3]}, ip)
  end

  test "#perform handles an anonymous function without arguments", %{ip: ip} do
    fun = fn -> "func/0" end

    assert "func/0" == Handler.perform(fun, ip)
    assert "func/0" == Handler.perform({fun, [1, 2, 3]}, ip)
  end

  test "#perform handles an anonymous function", %{ip: ip} do
    fun = fn val -> "func/1 (#{val})" end

    assert "func/1 (foo)" == Handler.perform(fun, ip)
    assert "func/1 (foo)" == Handler.perform({fun, [1, 2, 3]}, ip)
  end

  test "#perform handles an anonymous function with static arguments", %{ip: ip} do
    fun = fn val, args -> "func/2 (#{val}, #{inspect(args)})" end

    assert "func/2 (foo, [1, 2, 3])" == Handler.perform({fun, [1, 2, 3]}, ip)
    assert "func/2 (foo, [])" == Handler.perform(fun, ip)
  end

  test "#perform handles an anonymous 3-arity function", %{ip: ip} do
    fun = fn val, args, %IP{} -> "func/3 (#{val}, #{inspect(args)}, IP)" end

    assert "func/3 (foo, [], IP)" == Handler.perform(fun, ip)
    assert "func/3 (foo, [1, 2, 3], IP)" == Handler.perform({fun, [1, 2, 3]}, ip)
  end
end
