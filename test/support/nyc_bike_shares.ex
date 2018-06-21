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

  use Pipette.Recipe
  alias Pipette.Stage

  def stages,
    do: %{
      IN: %Stage.Producer{
        fun: fn -> "http://feeds.citibikenyc.com/stations/stations.json" end
      },
      fetch: %Stage{module: GetHTTP},
      station_list: %Stage{module: Pick, args: "stationBeanList"},
      station_count: %Stage{fun: fn list -> Enum.count(list) end},
      filter: %Stage{module: Filter, args: %{key: "stationName", value: "W 52 St & 11 Ave"}},
      station: %Stage{module: List, function: :first}
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
