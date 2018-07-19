defmodule Pipette.Stage.Recipe do
  @moduledoc """
  This consumer/producer stage can be used to include one recipe within another.

  The included recipe is expected to provide `:IN` and `:OUT` stages that implement the `Pipette.Client` protocol.
  """

  defstruct recipe: nil,
    timeout: :infinity
  @typedoc """
  An instance of a recipe stage.

  * `timeout:` provide an optional timeout that limits the execution time of the included recipe.
  """
  @type t :: %Pipette.Stage.Recipe{recipe: Pipette.Recipe.t, timeout: integer}

  use Pipette.GenStage
  alias Pipette.Client
  alias Pipette.IP

  @doc false
  def init(stage) do
    {:ok, controller} = Pipette.Controller.start_link(stage.recipe, name: nil)
    {:ok, client} = Client.start_link(controller)
    state = %{
      stage: stage,
      controller: controller,
      client: client
    }

    dispatcher = {GenStage.BroadcastDispatcher, []}
    {:producer_consumer, state, dispatcher: dispatcher}
  end

  @doc false
  def handle_events([ip], _from, %{stage: stage, client: client} = state) do
    new_value = Client.call(client, ip.value, stage.timeout)
    new_ip = IP.update(ip, new_value)
    {:noreply, [new_ip], state}
  end

end

