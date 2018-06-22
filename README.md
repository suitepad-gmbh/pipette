# Pipette

Pipette is flow-based programming engine for Elixir.

It utilizes `GenStage` to chain asynchronous processing stages, supporting multiple outlets and
routing.

One benefit of flow-based programming is to narrow the gap between prototype and production of
data processing systems.

## Flow-based programming

_This is not to be confused with `Flow`, an excellent library for data processing, also built on GenStage._

> In computer programming, flow-based programming (FBP) is a programming paradigm that defines applications as networks of "black box" processes, which exchange data across predefined connections by message passing, where the connections are specified externally to the processes. These black box processes can be reconnected endlessly to form different applications without having to be changed internally. FBP is thus naturally component-oriented.

Pipette implements these ideas, by utilizing GenStage as its underlying asynchronous message bus.

### Glossary

Our Glossary can be best explained with this diagram:
![recipe](https://user-images.githubusercontent.com/21111/41778061-bd6ef5e6-762d-11e8-89e4-c654d1bb5a16.png)

#### Stage

The central building part is called a `Stage`, in reminescence of the underlying `GenStage` this
system is built upon.

The stage holds all the information that is needed to act on a piece of data.

#### Subscription

A subscription is a defined connection between two externally labelled `Stage`s.
These subscriptions, map to what FBP commonly calls connections, and are the key to the flexibility
of such systems.

#### Recipe

A recipe is a group of `Stage`s that together with its subscriptions form a labelled graph, that
defines the path of execution.
In the FBP, this is the place where we provide the external connection information.

By default, all recipes come with an `:IN` and `:OUT` stage, that represents the standard outlets
a recipe can communicate with.

That should not stop you from implementing your very own labels and outlets, but for convenience
having a defined in and out label helps a lot building interfaces around a recipe.

#### IP (Information Packet)

In the FBP paradigm, the data flows within an envelope that is commonly called 'IP'. We don't necessarily
exhibit this struct, but when you are implementing a specific stage you will come across the IP.

It wraps the value, route and optional context information, and the `Pipette.IP` module provides
functions to safely modify them.

### Routing, Subscriptions

There are two key mechanisms that represent the FBP routing paradigm.
First and foremost, it is possible to define labelled outlets that can be used to interact
with a set of stages.

By default, a Recipe will provide you with an IN- and OUT outlet, that you can use to call and receive
messages from the processing network.

In most examples you will see, that we subscribe IN and OUT stages explicitly.

Second, on any producing outlet, you can setup a subscription that only received messages for a specific routing key.

This is tremendously helpful to divert message streams, and handle errors. Erlang and Elixir have this
widespread concept of returning a 2-tuple for denoting the return state of a function call.

We leveraged this concept into our routing mechanism, so that any 2-tuple return value of type `{atom(), any()}`
will be recognised as a value with a routing key.

Therefore all shorthand noted subscriptions, will be expanded to their full form:

`{from, to}` -> `{from, {to, :ok}}`

There is one special label `:*` and routing key `:*`.
These signal, that all stages should be subscribed to, respectively all messages should be received from any routing key.

So you can subscribe a stage to all routes of a particular stage:

`{from, {to, :*}}`

Or one stage to all producing stages in the recipe:

`{from, :*}` -> `{from, {:*, :ok}}`

And you can subscribe a stage to all other producing stages, with on all routes:

`{from, {:*, :*}}`

Commonly you want to setup one `error_handler` stage in your recipe like this:

`{from, {:*, :error}}`

It would then receive all messages returned as `{:error, value}` and exceptions that were rescued
during the execution of any producing stage.

#### Routing example

The following is a great example on how you can focus on getting the core value done and
when wired up correctly, the system will deal with errors, and working requests will flow through.

```elixir
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
```

### Types of networks

Pipette can help you realize the following types of data processing networks:

* Pull-based
* Push-based
* Call-based


## Development

```console
$ mix deps.get
% mix test
```

