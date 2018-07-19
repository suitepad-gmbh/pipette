defmodule Pipette.Stage.PushProducer do
  @moduledoc """
  A basic producer stage that emits values that it receives via a `GenStage.cast/2`.

  This is the default `:IN` stage of any `Pipette.Recipe`.
  """
  use Pipette.GenStage, stage_type: :producer

  defstruct id: nil
  @typedoc """
  An instance of a push producer.
  """
  @type t :: %Pipette.Stage.Sink{}


  @doc false
  def handle_cast(%Pipette.IP{} = ip, block) do
    {:noreply, [ip], block}
  end

  @doc false
  def handle_demand(_demand, block) do
    {:noreply, [], block}
  end
end
