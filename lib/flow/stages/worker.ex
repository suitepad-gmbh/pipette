defmodule Flow.Stages.Worker do
  @moduledoc """
  A process executing code components.
  """

  alias Flow.IP
  alias Flow.Stage

  use GenStage

  def start_link(stage, opts \\ []) do
    GenStage.start_link(__MODULE__, stage, opts)
  end

  def init(stage) do
    subscription = Enum.map(stage.producers, &({&1, max_demand: 1}))
    {:producer_consumer, stage, subscribe_to: subscription}
  end

  def handle_events([%IP{is_error: true} = ip], _from, stage) do
    {:noreply, [ip], stage}
  end

  def handle_events([ip], _from, stage) do
    new_ip = Stage.perform(stage, ip)
    {:noreply, [new_ip], stage}
  end

end

