defmodule Flow.Stages.Consumer do

  alias Flow.IP

  use GenStage

  def start_link(outlets, opts \\ []) do
    GenStage.start_link(__MODULE__, outlets, opts)
  end

  def init(outlets) do
    subscribe_to = Enum.map(outlets, &({&1,  max_demand: 1}))
    {:consumer, nil, subscribe_to: subscribe_to}
  end

  def handle_events([%IP{reply_to: pid} = ip], _from, nil) when is_pid(pid) do
    send(pid, ip)
    {:noreply, [], nil}
  end

  def handle_events([%IP{}], _from, nil) do
    {:noreply, [], nil}
  end

end

