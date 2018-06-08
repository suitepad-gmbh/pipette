defmodule Flow.IPTest do
  use ExUnit.Case

  alias Flow.IP

  test "#new takes a value and returns an IP struct" do
    assert %IP{value: :foo} == IP.new(:foo)
  end

  test "#new takes a conventional tuple and returns an IP struct with a route" do
    assert %IP{value: :foo, route: :ok} == IP.new({:ok, :foo})
    assert %IP{value: :foo, route: :bar} == IP.new({:bar, :foo})
    assert %IP{value: "something went wrong", route: :error} == IP.new({:error, "something went wrong"})
    assert %IP{value: {:bar, :foo}, route: :ok} == IP.new({:ok, {:bar, :foo}})
  end

  test "#new takes unconventional tuples and returns them as value, and routes them as :ok" do
    tuple = {"whatever", "someother protocol"}
    assert %IP{value: tuple, route: :ok} == IP.new(tuple)
  end

  test "#new takes reply_to as an additional argument" do
    pid = self()
    assert %IP{value: :foo, reply_to: pid} == IP.new(:foo, reply_to: pid)
  end

  test "#update takes a new value and updates the given ip" do
    pid = self()
    ip = %IP{value: :foo, route: :from, reply_to: pid}
    assert %IP{value: :bar, route: :ok, reply_to: ^pid} = IP.update(ip, :bar)
    assert %IP{value: :bar, route: :somewhere, reply_to: ^pid} = IP.update(ip, {:somewhere, :bar})
  end

  test "#set_context puts a key onto the context" do
    context = %{zig: "zag"}
    ip = %IP{value: "foo", route: :ok, context: context}

    new_ip = IP.set_context(ip, :meta, "some value")
    assert new_ip.context == Map.put(context, :meta, "some value")

    new_ip = IP.set_context(ip, :zig, "blubb")
    assert new_ip.context == %{context | zig: "blubb"}
  end
end
