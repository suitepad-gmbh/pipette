defmodule NYCBikeShares do
  defmodule Pick do
    def call(map, key: key) when is_map(map) do
      Map.get(map, key)
    end
  end

  defmodule Filter do
    def call(list, key: k, value: v) when is_list(list) do
      Enum.filter(list, &(&1[k] == v))
    end
  end

  defmodule GetHTTP do
    def call(url) do
      %HTTPoison.Response{body: body} = HTTPoison.get!(url)
      Jason.decode!(body)
    end
  end

  use Pipette.Recipe
  alias Pipette.Stage

  def stages,
    do: %{
      IN: %Stage.Producer{
        handler: fn -> "http://feeds.citibikenyc.com/stations/stations.json" end
      },
      fetch: %Stage{handler: GetHTTP},
      station_list: %Stage{handler: {Pick, key: "stationBeanList"}},
      station_count: %Stage{handler: fn list -> Enum.count(list) end},
      filter: %Stage{handler: {Filter, key: "stationName", value: "W 52 St & 11 Ave"}},
      station: %Stage{handler: &List.first/1}
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
