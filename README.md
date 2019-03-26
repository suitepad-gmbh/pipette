# Pipette

Pipette is flow-based programming (FBP) framework for Elixir.

It utilizes `GenStage` to chain asynchronous processing stages, supporting loose connections and
routing.

One benefit of flow-based programming is to narrow the gap between prototype and production of
data processing systems.

## Flow-based programming

> In computer programming, flow-based programming (FBP) is a programming paradigm that
> defines applications as networks of "black box" processes, which exchange data
> across predefined connections by message passing,
> where the connections are specified externally to the processes.
>
> These black box processes can be reconnected endlessly
> to form different applications without having to be changed internally.
>
> [_Wikipedia_](https://en.wikipedia.org/wiki/Flow-based_programming)

## Documentation

* [Documentation](https://hexdocs.pm/pipette/Pipette.html#content)
* [API Reference](https://hexdocs.pm/pipette/api-reference.html#content)
* [Example: Google Bot Verification](https://hexdocs.pm/pipette/google_bot_verification.html#content)

## Installation

```
{:pipette, "~> 0.1.0"},
```

## Development

```console
$ mix deps.get
% mix test
```

## Special thanks

* [Suitepad GmbH](https://suitepad.de/)

  Suitepad was sponsoring the development and release of this project.
  Their development team ([@spieker](https://github.com/spieker), [@theharq](https://github.com/theharq) and [@Rio517](https://github.com/Rio517))
  was heavily involved with the development of this library.

* [Masashi Iizuka](https://github.com/liquidz)

  Masashi was so nice to let us use `Pipette` as a project / library name.
  Pipette was formerly a EEx templating wrapper. [See this repository](https://github.com/liquidz/_dead_repo_pipette_)
