# Flow-based programming

This repository is the beginning of a Pipette-based programming engine for Elixir.

## IPs, Stages and Recipes

#### Introduction

The latest experiment shows a serializable data structure, a `%Recipe{}` that contains
`%Stage{}`-type elements.

This can be used to either programmatically create recipes and link stages together.
The main work the `Recipe` module takes over is to link the labels from stages to `GenStage` process ids.

Then it is also capable to link these stages together, by specifying the subscriptions that make up
the network that these stages are connected to each.

Utilizing `GenStage.BroadcastDispatcher` we can subscribe multiple stages to the same output.
By utilizing the `:selector` option, a routing concept could be implemented.
Thus it is possible to divert Pipettes into multiple outputs with a simple `{:route, value}` response.

By default simple `value`-term responses are just mapped to `{:ok, ip}`. Errors during execution
are mapped to `{:error, error_ip}`. This simple routing mechanism makes error handling a part of the system.

Go checkout [`test/support/nyc_bike_shares.ex`](https://github.com/suitepad-gmbh/it3_playground/blob/master/test/support/nyc_bike_shares.ex) for a real world example.

#### Types of networks

The above concept can be utilized to realize various types of data processing networks.

* Pull-based
* Push-based
* Parallel processing (not yet implemented/formalised)


### IP

An IP is the internal message envelope, in Pipette-based programming lingo an **information packet**.
The IP holds a value, routing information and is capable of wrapping errors.

### Stage

A block contains all information to build a stage.
Stages can describe all common `GenStage` types, like producers, streams,
producer/consumers and consumer stages.

A block can be labeled:

```elixir
%Stage{id: :label}
```

Its functionality can be passed in three ways:

* An anonymous function

  ```elixir
  %Stage{fun: &(&1 + 1)}
  ```

* A module/function

  ```elixir
  %Stage{module: Map, function: :values}
  ```

* A stream (producer only)

  ```elixir
  %Stage{type: :producer, stream: Stream.cycle(1..5)}
  ```

### Recipe

This is the simplest I could come up with, to build a graph of multiple labeled stages.
A recipe combines stages into a graph of `GenStage`s.

Once defined, a recipe can be used to start/establish all stages.
It does so by providing a dynamic supervisor that starts each stage and monitors it.

It holds stages:

```elixir
%Recipe{
  stages: [
    %Stage{id: :generator, type: :producer, stream: Stream.cycle(1..10)},
    %Stage{id: :add_one, fun: &(&1 + 1)}
  ]
}
```

And defines the subscriptions between them:

```elixir
%Recipe{
  subscriptions: [
    {:add_one, :generator}
  ]
}
```

## Development

```console
$ mix deps.get
% mix test
```

## Roadmap, ideas

- [x] Implement serializable structures for building a `GenStage` graph.
- [x] Real world example, fetching something from the internet and processing
- [x] Multiple lableld outputs
- [x] Error handling
- [ ] Test un-evenly routed streams
- [ ] Test minimal/maximal buffer sizes, congestion
- [ ] Parallel execution of single stages
- [ ] Provide an implementation to contextualise Recipes and Stage execution
- [ ] Show that networks can be connected with each other
- [ ] Provide convenience entry points similar to `Pipetteex.Client`
- [ ] Test supervisor/crash behaviour
- [ ] Implemented stage re-connection after fatal stage crashes
- [ ] Harden provided interface from bad inputs
- [ ] Re-integration into Elixir `Pipette`
