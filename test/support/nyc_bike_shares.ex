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

  @stage IN: %Stage.Producer{handler: fn -> "http://feeds.citibikenyc.com/stations/stations.json" end}
  @stage fetch: %Stage{handler: GetHTTP}
  @stage station_list: %Stage{handler: {Pick, key: "stationBeanList"}}
  @stage station_count: %Stage{handler: fn list -> Enum.count(list) end}
  @stage filter: %Stage{handler: {Filter, key: "stationName", value: "W 52 St & 11 Ave"}}
  @stage station: %Stage{handler: &List.first/1}

  @subscribe fetch: :IN
  @subscribe station_list: :fetch
  @subscribe filter: :station_list
  @subscribe station: :filter
  @subscribe station_count: :station_list
end
