defmodule GoogleBotVerification do
  use Pipette.OnDefinition

  @subscribe ptr_query: :IN
  @subscribe verify_domain: :ptr_query
  @subscribe dns_query: :verify_domain
  @subscribe verify: :dns_query
  @subscribe OUT: :verify
  @subscribe OUT: {:verify_domain, :error}

  def ptr_query(ip_addr) do
    in_addr = ip_addr
              |> String.split(".")
              |> Enum.reverse()
              |> Enum.join(".")
              |> Kernel.<>(".in-addr.arpa")

    {:ok, response} = "https://cloudflare-dns.com/dns-query"
                      |> HTTPoison.get([{"Accept", "application/dns-json"}], params: [name: in_addr, type: "PTR"])

    %{"Answer" => [%{"data" => domain} | _]} = Jason.decode!(response.body)

    %{ip_addr: ip_addr, domain: domain}
  end

  def verify_domain(%{domain: domain} = state) do
    if String.ends_with?(domain, ~w[google.com. googlebot.com.]) do
      {:ok, state}
    else
      {:error, :invalid_ptr}
    end
  end

  def dns_query(%{domain: domain} = state) do
    {:ok, response} = "https://cloudflare-dns.com/dns-query"
    |> HTTPoison.get([{"Accept", "application/dns-json"}], params: [name: domain, type: "A"])

    %{"Answer" => [%{"data" => domain_ip} | _]} = Jason.decode!(response.body)

    Map.put(state, :domain_ip, domain_ip)
  end

  def verify(%{ip_addr: ip_addr, domain_ip: domain_ip})
  when ip_addr == domain_ip, do: true

  def verify(_), do: false

end
