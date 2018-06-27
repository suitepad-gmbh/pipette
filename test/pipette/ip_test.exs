defmodule Pipette.IPTest do
  use ExUnit.Case

  alias Pipette.IP

  test "#new takes a value and returns an IP struct" do
    assert %IP{value: :foo} = IP.new(:foo)
  end

  test "#new takes a conventional tuple and returns an IP struct with a route" do
    assert %IP{value: :foo, route: :ok} = IP.new({:ok, :foo})
    assert %IP{value: :foo, route: :bar} = IP.new({:bar, :foo})

    assert %IP{value: "something went wrong", route: :error} =
             IP.new({:error, "something went wrong"})

    assert %IP{value: {:bar, :foo}, route: :ok} = IP.new({:ok, {:bar, :foo}})
  end

  test "#new takes unconventional tuples and returns them as value, and routes them as :ok" do
    tuple = {"whatever", "someother protocol"}
    assert %IP{value: ^tuple, route: :ok} = IP.new(tuple)
  end

  test "#new takes reply_to as an additional argument" do
    pid = self()
    assert %IP{value: :foo, reply_to: ^pid} = IP.new(:foo, reply_to: pid)
  end

  test "#update takes a new value and/or options and updates the given IP" do
    %IP{ref: ref, reply_to: pid} = ip = IP.new(:foo, reply_to: self())
    assert %IP{reply_to: ^pid, ref: ^ref, value: :bar} = IP.update(ip, :bar)

    assert %IP{reply_to: ^pid, ref: ^ref, value: {"hello", "world"}} =
             IP.update(ip, {"hello", "world"})

    assert %IP{reply_to: ^pid, ref: ^ref, route: :somewhere, value: :bar} =
             IP.update(ip, {:somewhere, :bar})

    assert %IP{reply_to: :me, ref: ^ref, value: :bar} = IP.update(ip, :bar, reply_to: :me)

    assert %IP{reply_to: :me, ref: ^ref, route: :somewhere, value: :bar} =
             IP.update(ip, {:somewhere, :bar}, reply_to: :me)

    assert %IP{reply_to: :me, ref: ^ref, value: :foo} = IP.update(ip, reply_to: :me)
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
