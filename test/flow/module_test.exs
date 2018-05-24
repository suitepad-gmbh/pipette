defmodule Flow.ModuleTest do
  use ExUnit.Case

  test "a module flow" do
    flow = Flow.Composer.start(FizzBuzzFlow.flow)
    result = Enum.map(1..15, fn i -> Flow.call(flow, i) end)
    assert result == ~w[1 2 fizz 4 buzz fizz 7 8 fizz buzz 11 fizz 13 14 fizzbuzz]
  end

end

