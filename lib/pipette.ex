defmodule Pipette do
  @moduledoc """
  Pipette is a flow-based programming (FBP) framework for Elixir.

  > In computer programming, flow-based programming (FBP) is a programming paradigm that
  > defines applications as networks of "black box" processes, which exchange data
  > across predefined connections by message passing,
  > where the connections are specified externally to the processes.
  >
  > These black box processes can be reconnected endlessly
  > to form different applications without having to be changed internally.
  >
  > [_Wikipedia_](https://en.wikipedia.org/wiki/Flow-based_programming)

  The paradigm allows a programmer to quickly write code, that can be tested in isolation and thus
  repurposed quickly.

  The framework is aimed to help quick prototyping while providing a clear path to bring the code to production.

  ## Building Blocks

  The framework provides multiple basic modules to write FBP applications.

  * `Pipette.Recipe`
  * `Pipette.Stage`
  * `Pipette.Stage.Consumer`
  * `Pipette.Stage.Sink`
  * `Pipette.Stage.Producer`
  * `Pipette.Stage.PushProducer`
  * `Pipette.Stage.Recipe`
  * `Pipette.IP`

  ## Helper modules

  In addition to the basic building blocks, there are multiple convenience modules, that help
  building, testing and interacting with FBP applications.

  * `Pipette.Client`
  * `Pipette.OnDefinition`
  * `Pipette.Test`
  * `Pipette.Handler`
  * `Pipette.GenStage`

  """
end
