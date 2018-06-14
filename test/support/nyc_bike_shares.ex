defmodule NYCBikeShares do
  defmodule Pick do
    def call(map, key) when is_map(map) do
      Map.get(map, key)
    end
  end

  defmodule Pluck do
    def call(list, keys) when is_list(list) do
      Enum.map(list, &Map.take(&1, keys))
    end
  end

  defmodule Filter do
    def call(list, %{key: k, value: v}) when is_list(list) do
      Enum.filter(list, &(&1[k] == v))
    end
  end

  defmodule GetHTTP do
    def call(url, _ \\ nil) do
      %HTTPoison.Response{body: body} = HTTPoison.get!(url)
      Jason.decode!(body)
    end
  end

  use Flow.Pattern

  def blocks,
    do: %{
      IN: %Flow.Block.Producer{
        fun: fn -> "http://feeds.citibikenyc.com/stations/stations.json" end
      },
      fetch: %Flow.Block{module: GetHTTP},
      station_list: %Flow.Block{module: Pick, args: "stationBeanList"},
      station_count: %Flow.Block{fun: fn list -> Enum.count(list) end},
      filter: %Flow.Block{module: Filter, args: %{key: "stationName", value: "W 52 St & 11 Ave"}},
      station: %Flow.Block{module: List, function: :first}
    }

  def subscriptions,
    do: [
      {:fetch, :IN},
      {:station_list, :fetch},
      {:filter, :station_list},
      {:station, :filter},
      {:station_count, :station_list}
    ]
end
