defmodule Pipette.Stage.Producer do
  @moduledoc """
  A basic producer stage that accepts either a `handler:` or `stream:` that will be used
  to emit values.

  A handler will be called for each demand request.

  A stream will be mapped and provided as
  a `GenStage.Streamer` to the network.
  """

  defstruct handler: nil,
            stream: nil
  @typedoc """
  An instance of a producer stage declaring a handler or stream.
  """
  @type t :: %Pipette.Stage.Producer{handler: Pipette.Handler.t, stream: Stream.t}

  alias Pipette.Stage
  alias Pipette.IP

  @doc false
  def child_spec(%Stage.Producer{stream: stream}) when not is_nil(stream) do
    ip_stream = stream |> Stream.map(&IP.new/1)
    arg = {ip_stream, dispatcher: GenStage.BroadcastDispatcher}
    %{id: GenStage.Streamer, start: {GenStage, :start_link, [GenStage.Streamer, arg]}}
  end

  use Pipette.GenStage, stage_type: :producer

  @doc false
  def handle_demand(demand, %__MODULE__{handler: handler} = stage) when demand > 0 do
    ips =
      Enum.map(1..demand, fn _ ->
        Pipette.Handler.call(handler, IP.new(nil))
      end)

    {:noreply, ips, stage}
  end
end
