defmodule Flow.Block.ProducerTest do
  use ExUnit.Case

  defmodule Test do
    def call(args \\ [timeout: 500]) do
      args[:timeout]
    end
  end

  alias Flow.Block.Producer
  alias Flow.Block.ProducerTest.Test

  test "#produce takes a module and uses :call as a function by default" do
    assert Producer.produce(%Producer{module: Test}) == 500
    assert Producer.produce(%Producer{module: Test, args: [timeout: 1000]}) == 1000
  end

  test "#produce takes an anonymous function without arguments" do
    assert Producer.produce(%Producer{fun: fn -> "some value" end}) == "some value"
  end

  test "#produce takes an anonymous function with arguments" do
    assert Producer.produce(%Producer{fun: fn x -> x+1 end, args: 1}) == 2
  end

end

