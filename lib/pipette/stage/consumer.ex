defmodule Pipette.Stage.Consumer do
  use Pipette.GenStage, stage_type: :consumer

  defstruct id: nil

  def handle_events([ip], _from, block) do
    if is_pid(ip.reply_to) do
      send(ip.reply_to, ip)
    end

    {:noreply, [], block}
  end
end
