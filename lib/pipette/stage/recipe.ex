defmodule Pipette.Stage.Recipe do

  defstruct recipe: nil,
    timeout: :infinity

  use Pipette.GenStage
  alias Pipette.Client
  alias Pipette.IP

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

  def handle_events([ip], _from, %{stage: stage, client: client} = state) do
    new_value = Client.call(client, ip.value, stage.timeout)
    new_ip = IP.update(ip, new_value)
    {:noreply, [new_ip], state}
  end

end

