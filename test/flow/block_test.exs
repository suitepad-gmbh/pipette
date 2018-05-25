defmodule Flow.BlockTest do
  use ExUnit.Case

  test "it works" do
    pattern = NYCBikeShares.data
              |> Flow.Pattern.start
              |> Flow.Pattern.connect

    {:ok, pid} = Flow.Pattern.outlet(pattern, :filter)

    GenStage.stream([pid], max_demand: 1)
    |> Stream.take(1)
    |> Enum.into([])
    |> IO.inspect

    {:ok, pid} = Flow.Pattern.outlet(pattern, :station_count)

    GenStage.stream([pid], max_demand: 1)
    |> Stream.take(1)
    |> Enum.into([])
    |> IO.inspect
  end
end

