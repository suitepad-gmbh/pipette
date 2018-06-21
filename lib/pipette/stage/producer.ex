defmodule Pipette.Stage.Producer do
  defstruct id: nil,
            fun: nil,
            module: nil,
            function: :call,
            stream: nil,
            args: nil

  alias Pipette.Stage
  alias Pipette.IP

  use Pipette.GenStage, stage_type: :producer

  def child_spec(%Stage.Producer{stream: stream}) when not is_nil(stream) do
    ip_stream = stream |> Stream.map(&IP.new/1)
    arg = {ip_stream, dispatcher: GenStage.BroadcastDispatcher}
    %{id: GenStage.Streamer, start: {GenStage, :start_link, [GenStage.Streamer, arg]}}
  end

  def handle_demand(demand, block) when demand > 0 do
    ips =
      Enum.map(1..demand, fn _ ->
        produce(block) |> IP.new()
      end)

    {:noreply, ips, block}
  end

  def produce(%Stage.Producer{fun: fun, args: args})
      when is_function(fun, 1) do
    fun.(args)
  end

  def produce(%Stage.Producer{fun: fun})
      when is_function(fun, 0) do
    fun.()
  end

  def produce(%Stage.Producer{module: module, function: function, args: nil})
      when is_atom(function) and module != nil do
    apply(module, function, [])
  end

  def produce(%Stage.Producer{module: module, function: function, args: args})
      when is_atom(function) and module != nil do
    apply(module, function, [args])
  end
end
