defmodule Flow.Block.Consumer do

  use GenStage

  defstruct id: nil

  def start_link(block, opts \\ []) do
    GenStage.start_link(__MODULE__, block, opts)
  end

  def init(block) do
    {:consumer, block}
  end

  def handle_events([ip], _from, block) do
    if is_pid(ip.reply_to) do
      send(ip.reply_to, ip)
    end
    {:noreply, [], block}
  end

end

