defmodule NYCBikeShares do

  defmodule Pick do
    def call(map, key) when is_map(map) do
      Map.get(map, key)
    end
  end

  defmodule Pluck do
    def call(list, keys) when is_list(list) do
      Enum.map(list, &(Map.take(&1, keys)))
    end
  end

  defmodule Filter do
    def call(list, %{key: k, value: v}) when is_list(list) do
      Enum.filter(list, &(&1[k] == v))
    end
  end

  defmodule GetHTTP do
    def call(url, _) do
      %HTTPoison.Response{body: body} = HTTPoison.get!(url)
      Jason.decode!(body)
    end
  end

  def data do
    %Flow.Pattern{
      blocks: [
        %Flow.Block{id: :url_generator, type: :producer, fun: fn -> "http://feeds.citibikenyc.com/stations/stations.json" end},
        %Flow.Block{id: :fetch, module: GetHTTP},
        %Flow.Block{id: :station_list, module: Pick, args: "stationBeanList"},
        %Flow.Block{id: :station_count, fun: fn list -> Enum.count(list) end},
        %Flow.Block{id: :filter, module: Filter, args: %{key: "stationName", value: "W 52 St & 11 Ave"}}
      ],
      connections: [
        {:filter, :station_list},
        {:station_list, :fetch},
        {:fetch, :url_generator},
        {:station_count, :station_list}
      ]
    }
  end

end
