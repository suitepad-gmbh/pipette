defmodule NYCBikeSharesTest do
  use ExUnit.Case

  test "real world example (requires internet connection)" do
    pattern = NYCBikeShares.data |> Flow.Pattern.start
    {:ok, client} = Flow.Client.start_link(pattern)

    %{"stationName" => _} = Flow.Client.pull(client, :station)
    assert is_number(Flow.Client.pull(client, :station_count))
  end

end

