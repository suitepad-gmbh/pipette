defmodule Pipette.Stage.Consumer do
  use Pipette.GenStage, stage_type: :consumer

  defstruct id: nil,
    handler: nil

  def handle_events([ip], _from, %__MODULE__{handler: handler} = stage) when is_nil(handler) do
    if is_pid(ip.reply_to) do
      send(ip.reply_to, ip)
    end

    {:noreply, [], stage}
  end

  def handle_events([ip], _from, %__MODULE__{handler: handler} = stage) do
    Pipette.Handler.handle(handler, ip)
    {:noreply, [], stage}
  end
end
