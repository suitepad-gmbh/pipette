defmodule Pipette.Stage do
  @moduledoc """
  The basic **producer/consumer** stage used to handle messages.

  See `Pipette.Handler` on how to provide handling modules/functions.
  """
  require Logger

  defstruct handler: nil

  @typedoc """
  An instance of a Stage specifying a handler.
  """
  @type t :: %Pipette.Stage{handler: Pipette.Handler.t}

  alias Pipette.IP
  use Pipette.GenStage, stage_type: :producer_consumer

  @doc false
  def handle_events([%IP{} = ip], _from, stage) do
    new_ip = process_ip(ip, stage)
    {:noreply, [new_ip], stage}
  end

  @doc false
  def handle_cast(%IP{} = ip, stage) do
    new_ip = process_ip(ip, stage)
    {:noreply, [new_ip], stage}
  end

  @doc false
  defp process_ip(%IP{} = ip, %__MODULE__{handler: handler} = stage) do
    Pipette.Handler.call(handler, ip)
  rescue
    error ->
      message = Exception.message(error)
      Logger.debug("error in #{inspect(stage)}: #{message}")

      wrapped = %{
        error: error,
        message: message,
        stage: stage
      }

      %IP{ip | route: :error}
      |> IP.set_context(:error, wrapped)
  end
end
