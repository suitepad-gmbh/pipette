defmodule Pipette.Stage.Consumer do
  @moduledoc """
  The basic **consumer** stage used to handle messages.

  See `Pipette.Handler` on how to provide handling modules/functions.
  """
  use Pipette.GenStage, stage_type: :consumer

  defstruct handler: nil

  @typedoc """
  An instance of a consumer stage specifying a handler.
  """
  @type t :: %Pipette.Stage.Consumer{handler: Pipette.Handler.t}

  @doc false
  def handle_events([ip], _from, %__MODULE__{handler: handler} = stage) when is_nil(handler) do
    if is_pid(ip.reply_to) do
      send(ip.reply_to, ip)
    end

    {:noreply, [], stage}
  end

  @doc false
  def handle_events([ip], _from, %__MODULE__{handler: handler} = stage) do
    Pipette.Handler.call(handler, ip)
    {:noreply, [], stage}
  end
end
