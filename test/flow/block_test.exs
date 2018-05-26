defmodule Flow.BlockTest do
  use ExUnit.Case

  alias Flow.Pattern
  alias Flow.Block

  test "real world example (requires internet connection)" do
    pattern = NYCBikeShares.data
              |> Pattern.start
              |> Pattern.establish

    {:ok, pid} = Pattern.get_stage(pattern, :filter)
    assert [
      %Flow.IP{value: [station]}
    ] = GenStage.stream([pid], max_demand: 1)
        |> Enum.take(1)

    {:ok, pid} = Pattern.get_stage(pattern, :station_count)
    assert [
      %Flow.IP{value: count}
    ] = GenStage.stream([pid], max_demand: 1)
        |> Enum.take(1)
  end

  test "hey, we could do routing this these" do
    pattern = %Pattern{
      blocks: [
        %Block{id: :divide_and_conquer, fun: fn
          n when rem(n, 2) == 0 -> {:even, n}
          n when rem(n, 2) != 0 -> {:odd, n}
        end},
        %Block{id: :make_even, fun: &({:even, &1 + 1})},
        %Block{id: :pass_even, fun: &({:even, &1})}
      ],
      connections: [
        {:make_even, {:divide_and_conquer, :odd}},
        {:pass_even, {:divide_and_conquer, :even}}
      ]
    }
    |> Pattern.start
    |> Pattern.establish

    {:ok, numbers} = Pattern.get_stage(pattern, :divide_and_conquer)

    {:ok, generator} = Stream.iterate(%Flow.IP{value: 1}, &(%Flow.IP{&1 | value: &1.value + 1})) |> GenStage.from_enumerable
    {:ok, _} = GenStage.sync_subscribe(numbers, to: generator, max_demand: 1)

    {:ok, stage_1} = Pattern.get_stage(pattern, :make_even)
    {:ok, stage_2} = Pattern.get_stage(pattern, :pass_even)

    assert [
      2, 2, 4, 4, 6, 6, 8, 8, 10, 10
    ] == GenStage.stream([stage_1, stage_2], max_demand: 1)
         |> Enum.take(10)
         |> Enum.map(&(&1.value))
  end

end

