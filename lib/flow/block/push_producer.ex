defmodule Flow.Block.PushProducer do
  use Flow.Stage, stage_type: :producer

  defstruct id: nil

  def handle_cast(%Flow.IP{} = ip, block) do
    {:noreply, [ip], block}
  end

  def handle_demand(_demand, block) do
    {:noreply, [], block}
  end
end
