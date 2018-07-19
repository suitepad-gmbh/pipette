# Example: Google Bot Verification using Reverse DNS queries

For example you need to write an application, that needs to identify the authenticity of
the GoogleBot based on connecting Client-IP.

This example shows, how Pipette can be used to quickly write a meaningful prototype,
that can effortlessly be transitioned to production.

## 1. How GoogleBot verification works

[The offical guide can be read here](https://support.google.com/webmasters/answer/80553?hl=en).

The application needs to:

1. Run a reverse DNS lookup (type PTR) on the accessing IP
2. Verify that the resulting domain name ends in `googlebot.com.` or `google.com.`
3. Run a forward DNS lookup (type A) on the resulting domain
4. Verify that the same IP belongs to the domain

In FBP, the application behaviour is mostly defined by the connections, that combine functional
blocks of execution.

Think of it, as a quick prototype, the mental model that we are building up for the application.

In Pipette, you can loosely formulate this with the follwowing module.
This is what first came to my mind, when thinking about the verification steps:

    defmodule GoogleBotVerification do
      @subscribe ptr_query: :IN
      @subscribe verify_domain: :ptr_query
      @subscribe dns_query: :verify_domain
      @subscribe verify: :dns_query
      @subscribe OUT: :verify
    end

You see that I am starting the application, by its connections. `:IN` and `:OUT` are explicitly
mentioned, since our recipe takes a given IP-address and should return the verifiation result.

## 2. Fill out the implementation

In the next step, lets implement each function.
The first thing, I am interested in, is to perform a PTR-type DNS query.
I am going to use the [Cloudflare HTTP-DNS API](https://developers.cloudflare.com/1.1.1.1/dns-over-https/) to faciliate simple DNS queries over HTTP.

    defmodule GoogleBotVerification do
      use Pipette.OnDefinition

      @subscribe ptr_query: :IN
      @subscribe verify_domain: :ptr_query
      @subscribe dns_query: :verify_domain
      @subscribe verify: :dns_query
      @subscribe OUT: :verify

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

    end

Now this `ptr_query/1` function does a lot. But we are fine during this phase of development,
testing it out reveals that it does its job nicely:

    GoogleBotVerification.ptr_query("66.249.66.1")
    # => %{domain: "crawl-66-249-66-1.googlebot.com.", ip_addr: "66.249.66.1"}

We will get to refactoring/reuse later. For now, we have decent state to work with.

Lets continue with the implementation. Next is to verify that the domain belongs to Google:

    defmodule GoogleBotVerification do
      # ... snip

      def verify_domain(%{domain: domain} = state) do
        result = String.ends_with?(domain, ~w[google.com. googlebot.com.])
        Map.put(state, :verify_domain, result)
      end
    end

And lets also implement the dns query, to also verify that the PTR response belongs to the IP that
is connecting to us:

    defmodule GoogleBotVerification do
      # ... snip

      def dns_query(%{domain: domain} = state) do
        {:ok, response} = "https://cloudflare-dns.com/dns-query"
        |> HTTPoison.get([{"Accept", "application/dns-json"}], params: [name: domain, type: "A"])

        %{"Answer" => [%{"data" => domain_ip} | _]} = Jason.decode!(response.body)

        Map.put(state, :domain_ip, domain_ip)
      end
    end

Which works just as well as the reverse lookup:

    GoogleBotVerification.dns_query(%{domain: "crawl-66-249-66-1.googlebot.com."})
    # => %{domain: "crawl-66-249-66-1.googlebot.com.", domain_ip: "66.249.66.1"}

Last but not least, the overall verification step. In this function, we want to compare
that the given ip address and the dns query return the same result, and that the domain verification
matched.

    defmodule GoogleBotVerification do
      # ... snip

      def verify(%{verify_domain: false}), do: false

      def verify(%{verify_domain: true, ip_addr: ip_addr, domain_ip: domain_ip})
      when ip_addr == domain_ip, do: true

      def verify(_), do: false
    end

## 3. Test-drive the first version

The whole application can be now be started, and interacted with:

    controller = Pipette.Recipe.start_controller(GoogleBotVerification.recipe)
    client = Pipette.Client.start(controller)

    Pipette.Client.call(client, "66.249.66.1")
    # => {:ok, true}

    Pipette.Client.call(client, "127.0.0.1")
    # => {:ok, false}

Now obviously, the current state of the module is just a quick draft. There are some rough areas that
need refactoring, and can be prepared for re-use.

Also, we do not need to verify the domain, if the reverse lookup ends up in something
else than `google.com.` or `googlebot.com.`.

## 4. Refactor the domain verification using Pipette routing

I will start by omitting the dns query if the domain lookup does not match the expected domains.
This can be done by _routing_ the results properly. In Elixir, a common way to determine the success
state of a function is to return either a `{:ok, result}` or `{:error, result}` tuple.

Pipette uses 2-tuple return values (e.g. `{atom(), any()}`) as part of its routing mechanism.

    defmodule GoogleBotVerification do
      # ... snip

      def verify_domain(%{domain: domain} = state) do
        if String.ends_with?(domain, ~w[google.com. googlebot.com.]) do
          {:ok, state}
        else
          {:error, :invalid_ptr}
        end
      end
    end

Now lets rewire the subscriptions, and also subscribe `:OUT` to the error outputs:

    defmodule GoogleBotVerification do
      @subscribe ptr_query: :IN
      @subscribe verify_domain: :ptr_query
      @subscribe dns_query: :verify_domain
      @subscribe verify: :dns_query
      @subscribe OUT: :verify
      @subscribe OUT: {:verify_domain, :error}

      # ... snip
    end

The final `verify/1` is reduced to two clauses:

    defmodule GoogleBotVerification do
      # ... snip

      def verify(%{ip_addr: ip_addr, domain_ip: domain_ip})
      when ip_addr == domain_ip, do: true

      def verify(_), do: false
    end

With this, our recipe can be called from a client.

    Pipette.Client.call(client, "127.0.0.1")
    # => {:error, :invalid_ptr}

## 5. Make DNS queries re-usable components

Let start out by extracting a generic module, that does DNS queries.

I am going to write a simple `HTTPoison.Base` module, that does basic DNS queries for me.
This module uses the public [Cloudflare HTTP-DNS API](https://developers.cloudflare.com/1.1.1.1/dns-over-https/) to faciliate simple DNS queries.

    defmodule DNSLookup do
      use HTTPoison.Base

      def process_url(url), do: "https://cloudflare-dns.com/dns-query" <> url
      def process_request_headers(headers), do: headers ++ [{"Accept", "application/dns-json"}]
      def process_response_body(binary), do: Jason.decode!(binary)

      def query(name, type \\\\ "A") do
        {:ok, response} = get("", [], params: [name: name, type: type])
        Map.get(response.body, "Answer")
      end

      def ptr(ip) do
        ip
        |> String.split(".")
        |> Enum.reverse()
        |> Enum.join(".")
        |> Kernel.<>(".in-addr.arpa")
        |> short("PTR")
      end

      def short(name, type \\\\ "A") do
        query(name, type)
        |> Enum.map(&(Map.get(&1, "data")))
      end
    end

Now the `GoogleBotVerification` implementation changes slightly, being more concerned about its use case:

    defmodule GoogleBotVerification do
      # ... snip

      def ptr_query(ip_addr) do
        [domain |_] = DNSLookup.ptr(ip_addr)
        %{ip_addr: ip_addr, domain: ptr}
      end

      def dns_query(%{domain: domain} = state) do
        [ip |_] = DNSLookup.short(domain)
        Map.put(state, :domain_ip, ip)
      end

      # ... snip
    end

## 6. Make the application production ready

Production depends how this recipe will be invoked, and how results are going to be handled.

I can image, that this is being called within a event-processing facility that manages a ban-list
of IP addresses that state to be Googlebot when in fact they are not.

Another use case could be a HTTP-service, that exposes the functionality as an API.

Either way, Pipette now allows you to change the execution pattern of this recipe with ease.
We can freely redefine the `:IN` and `:OUT` stages to fit the environment, we are going to run this recipe in.

Lets take the example of the event-processing facility, and assume we are using AMQP to hook up to
message queues.

In Pipette you can easily write your own `Pipette.Stage` implementation, that implements either of
a **producer**, **consumer** or **producer/consumer** `GenStage`.

Using labelled connections and routing, you can easily integrate this recipe with such a messaging system,
and handle both the happy-path as well as errors.

The changes to the system are minimal:

    defmodule GoogleBotVerification do

      @stage IN: %AMQP.Consumer{exchange: "access-logs", routing_key: "mysite.com"}
      @stage OUT: %AMPQ.Meta{handler: {AMPQ.Meta, :ack}}
      @stage errors: %Pipette.Sink{}

      # ... snip

      @subscribe :OUT, :verify
      @subscribe :errors, {:*, :error}

      # ... snip

    end

Another aspect for running in production is error handling.
We might want to install a generic error consumer that handles all errors, logs them and sends them
to the specific error handling service.

The following code would subscribe the `error_handler/1` function to all (i.e. `:*`) stages on the `:error` route.
The good thing is, that errors raised during execution are being handled by Pipette, and routed as `{:error, error}` tuples.

    defmodule GoogleBotVerification do
      require Logger

      # ... snip
      @subscribe :error_handler, {:*, :error}

      def error_handler(error_value) do
        Logger.error("event#error module=GoogleBotVerification value=\#{inspect error_value}")
        Sentry.capture_message("GoogleBotVerification.error", extra: %{value: error_value})
      end

      # ... snip

    end

## 7. Extend the application

Over the lifetime of such integrations, you often need to extend the system, to account for changing
needs and additional functionality.

Assuming you also want to count valid Googlebots in your StatsD system, you can do that simply by
adding another consumer stage, and subscribe it to the correct output:

    defmodule GoogleBotVerification do
      # ... snip

      @subscribe :stats, :verify

      def stats(true), do: StatsD.increment("google_bot.valid")
      def stats(_), do: nil
    end

## Final refactored code with logging on all errors

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
