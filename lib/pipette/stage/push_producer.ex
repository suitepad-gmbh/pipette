defmodule Pipette.Stage.PushProducer do
  use Pipette.GenStage, stage_type: :producer

  defstruct id: nil

  def handle_cast(%Pipette.IP{} = ip, block) do
    {:noreply, [ip], block}
  end

  def handle_demand(_demand, block) do
    {:noreply, [], block}
  end
end
