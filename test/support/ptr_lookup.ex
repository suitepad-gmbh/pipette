defmodule PTRLookup do
  use Pipette.OnDefinition
  require Logger

  @subscribe reverse_ip: :IN
  @subscribe dns_query: :reverse_ip
  @subscribe json: :dns_query
  @subscribe pick_data: :json
  @subscribe OUT: :pick_data

  @stage errors: %Pipette.Stage.Consumer{handler: fn
    reason ->
      Logger.error("There was an error: #{inspect reason}")
  end}
  @subscribe errors: {:*, :error}

  def reverse_ip(address) when is_binary(address) do
    address
    |> String.split(".")
    |> Enum.reverse()
    |> Enum.join(".")
  end

  def dns_query(reversed_address) do
    in_addr = "#{reversed_address}.in-addr.arpa"
    "https://cloudflare-dns.com/dns-query"
    |> HTTPoison.get([{"Accept", "application/dns-json"}], params: [name: in_addr, type: "PTR"])
  end

  def json(%HTTPoison.Response{status_code: 200, body: body}) do
    Jason.decode(body)
  end

  def pick_data(%{"Answer" => [%{"data" => data} | _]}) do
    data
  end
end

