defmodule Pipette.Stage.Sink do
  @moduledoc """
  A **consumer** stage that discards values, but creates demand to pull messages on the
  subscribed routes.

  This is useful in pull-based networks, that have branches beside the stages connected to an `:OUT`,
  but the side effects of the branch must be triggered.
  """

  @typedoc """
  An instance of a sink.
  """
  @type t :: %Pipette.Stage.Sink{}

  use Pipette.GenStage, stage_type: :consumer

  defstruct id: nil

  @doc false
  def handle_events([_ip], _from, block) do
    {:noreply, [], block}
  end
end
