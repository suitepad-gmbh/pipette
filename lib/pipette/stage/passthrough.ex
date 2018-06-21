defmodule Pipette.Stage.Passthrough do
  defstruct id: nil

  use Pipette.GenStage, stage_type: :producer_consumer

  def handle_events([ip], _from, block) do
    {:noreply, [ip], block}
  end
end
