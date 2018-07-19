# Glossary

Our Glossary can be best explained with this diagram:
![recipe](https://user-images.githubusercontent.com/21111/41778061-bd6ef5e6-762d-11e8-89e4-c654d1bb5a16.png)

## Stage

The central building part is called a `Stage`, in reminescence of the underlying `GenStage` this
system is built upon.

The stage holds all the information that is needed to act on a piece of data.

## Subscription

A subscription is a defined connection between two externally labelled `Stage`s.
These subscriptions, map to what FBP commonly calls connections, and are the key to the flexibility
of such systems.

## Recipe

A recipe is a group of `Stage`s that together with its subscriptions form a labelled graph, that
defines the path of execution.
In the FBP, this is the place where we provide the external connection information.

By default, all recipes come with an `:IN` and `:OUT` stage, that represents the standard outlets
a recipe can communicate with.

That should not stop you from implementing your very own labels and outlets, but for convenience
having a defined in and out label helps a lot building interfaces around a recipe.

## IP (Information Packet)

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
