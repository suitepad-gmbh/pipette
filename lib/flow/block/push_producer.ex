defmodule Flow.Block.PushProducer do

  use GenStage

  defstruct id: nil

  def start_link(block, opts \\ []) do
    GenStage.start_link(__MODULE__, block, opts)
  end

  def init(block), do: {:producer, block}

  def handle_cast(%Flow.IP{} = ip, block) do
    {:noreply, [ip], block}
  end

  def handle_demand(_demand, block) do
    {:noreply, [], block}
  end

end

