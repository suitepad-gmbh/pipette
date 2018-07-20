defmodule Pipette.Stage.Producer do
  defstruct handler: nil,
            stream: nil

  alias Pipette.Stage
  alias Pipette.IP

  def child_spec(%Stage.Producer{stream: stream}) when not is_nil(stream) do
    ip_stream = stream |> Stream.map(&IP.new/1)
    arg = {ip_stream, dispatcher: GenStage.BroadcastDispatcher}
    %{id: GenStage.Streamer, start: {GenStage, :start_link, [GenStage.Streamer, arg]}}
  end

  use Pipette.GenStage, stage_type: :producer

  def handle_demand(demand, %__MODULE__{handler: handler} = stage) when demand > 0 do
    ips =
      Enum.map(1..demand, fn _ ->
        Pipette.Handler.call(handler, IP.new(nil))
      end)

    {:noreply, ips, stage}
  end
end
