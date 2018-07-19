defmodule GoogleBotVerification do
  require Logger

  use Pipette.OnDefinition

  @subscribe ptr_query: :IN
  @subscribe verify_domain: :ptr_query
  @subscribe dns_query: :verify_domain
  @subscribe verify: :dns_query
  @subscribe OUT: :verify
  @subscribe OUT: {:verify_domain, :error}
  @subscribe log_errors: {:*, :error}

  @stage log_errors: %Stage.Consumer{handler: fn error ->
    Logger.error("GoogleBotVerification error: \#{inspect error}")
  end}

  def ptr_query(ip_addr) do
    domain = DNSLookup.ptr(ip_addr)
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
    [domain_ip |_] = DNSLookup.short(domain)
    Map.put(state, :domain_ip, domain_ip)
  end

  def verify(%{ip_addr: ip_addr, domain_ip: domain_ip})
  when ip_addr == domain_ip, do: true

  def verify(_), do: false

end
