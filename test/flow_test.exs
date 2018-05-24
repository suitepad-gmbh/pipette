defmodule FlowTest do
  use ExUnit.Case

  alias Flow.Stage

  test "a simple flow" do
    flow = %Flow{
      stages: [
        %Stage{fun: fn x -> x + 1 end},
        %Stage{fun: fn
          x when rem(x, 2) == 0 -> {:even, x}
          x -> {:odd, x}
        end}
      ]
    } |> Flow.Composer.start
    assert {:even, 2} = Flow.call(flow, 1)
    assert {:odd, 1} = Flow.call(flow, 0)
  end

  # test "a flow with different outlets" do
  #   flow = %Flow{
  #     stages: [
  #       %Stage{fun: fn
  #         x when rem(x, 2) == 0 -> {:even, x}
  #         x -> {:odd, x}
  #       end},
  #       %Router{hash: {:elem, 0}}
  #     ],
  #     outlets: [:even, :odd]
  #   }
  #   Enum.each(1..8, fn i -> Flow.cast(flow, i) end)
  #   assert [2, 4, 6, 8] == Flow.stream(flow, outlet: :even) |> Enum.into([])
  #   assert [1, 3, 5, 7] == Flow.stream(flow, outlet: :odd) |> Enum.into([])
  # end

end

