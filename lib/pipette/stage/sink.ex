defmodule Pipette.Stage.Sink do
  use Pipette.GenStage, stage_type: :consumer

  defstruct id: nil

  def handle_events([_ip], _from, block) do
    {:noreply, [], block}
  end
end
