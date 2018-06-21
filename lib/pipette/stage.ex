defmodule Pipette.Stage do
  require Logger

  defstruct handler: nil

  alias Pipette.IP
  use Pipette.GenStage, stage_type: :producer_consumer

  def handle_events([%IP{} = ip], _from, stage) do
    new_ip = process_ip(ip, stage)
    {:noreply, [new_ip], stage}
  end

  def handle_cast(%IP{} = ip, stage) do
    new_ip = process_ip(ip, stage)
    {:noreply, [new_ip], stage}
  end

  defp process_ip(%IP{} = ip, %__MODULE__{handler: handler} = stage) do
    Pipette.Handler.handle(handler, ip)
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
