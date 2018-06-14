defmodule Flow.Block.Sink do
  use Flow.Stage, stage_type: :consumer

  defstruct id: nil

  def handle_events([_ip], _from, block) do
    {:noreply, [], block}
  end
end
