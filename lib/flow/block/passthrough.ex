defmodule Flow.Block.Passthrough do
  defstruct id: nil

  use Flow.Stage, stage_type: :producer_consumer

  def handle_events([ip], _from, block) do
    {:noreply, [ip], block}
  end
end
