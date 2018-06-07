defmodule NYCBikeSharesTest do
  use ExUnit.Case

  setup_all do
    {:ok, _pid} = NYCBikeShares.start_link()
    :ok
  end

  test "real world example (requires internet connection)" do
    {:ok, client} = Flow.Client.start_link(NYCBikeShares)

    %{"stationName" => _} = Flow.Client.pull(client, :station)
    assert is_number(Flow.Client.pull(client, :station_count))
  end

end

