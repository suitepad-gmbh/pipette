# Flow-based programming

This repository is the beginning of a Flow-based programming engine for Elixir.

## IPs, Blocks and Patterns

#### Introduction

The latest experiment shows a serializable data structure, a `%Pattern{}` that contains
`%Block{}`-type elements.

This can be used to either programmatically create patterns and link blocks together.
The main work the `Pattern` module takes over is to link the labels from blocks to `GenStage` process ids.

Then it is also capable to link these stages together, by specifying the subscriptions that make up
the network that these stages are connected to each.

Utilizing `GenStage.BroadcastDispatcher` we can subscribe multiple stages to the same output.
By utilizing the `:selector` option, a routing concept could be implemented.
Thus it is possible to divert flows into multiple outputs with a simple `{:route, value}` response.

By default simple `value`-term responses are just mapped to `{:ok, ip}`. Errors during execution
are mapped to `{:error, error_ip}`. This simple routing mechanism makes error handling a part of the system.

Go checkout [`test/support/nyc_bike_shares.ex`](https://github.com/suitepad-gmbh/it3_playground/blob/master/test/support/nyc_bike_shares.ex) for a real world example.

#### Types of networks

The above concept can be utilized to realize various types of data processing networks.

* Pull-based
* Push-based
* Parallel processing (not yet implemented/formalised)


### IP

An IP is the internal message envelope, in Flow-based programming lingo an **information packet**.
The IP holds a value, routing information and is capable of wrapping errors.

### Block

A block contains all information to build a stage.
Blocks can describe all common `GenStage` types, like producers, streams,
producer/consumers and consumer stages.

A block can be labeled:

```elixir
%Block{id: :label}
```

Its functionality can be passed in three ways:

* An anonymous function

  ```elixir
  %Block{fun: &(&1 + 1)}
  ```

* A module/function

  ```elixir
  %Block{module: Map, function: :values}
  ```

* A stream (producer only)

  ```elixir
  %Block{type: :producer, stream: Stream.cycle(1..5)}
  ```

### Pattern

This is the simplest I could come up with, to build a graph of multiple labeled stages.
A pattern combines blocks into a graph of `GenStage`s.

Once defined, a pattern can be used to start/establish all stages.
It does so by providing a dynamic supervisor that starts each stage and monitors it.

It holds blocks:

```elixir
%Pattern{
  blocks: [
    %Block{id: :generator, type: :producer, stream: Stream.cycle(1..10)},
    %Block{id: :add_one, fun: &(&1 + 1)}
  ]
}
```

And defines the subscriptions between them:

```elixir
%Pattern{
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
- [ ] Provide an implementation to contextualise Patterns and Block execution
- [ ] Show that networks can be connected with each other
- [ ] Provide convenience entry points similar to `Flowex.Client`
- [ ] Test supervisor/crash behaviour
- [ ] Implemented stage re-connection after fatal stage crashes
- [ ] Harden provided interface from bad inputs
- [ ] Re-integration into Elixir `Flow`


