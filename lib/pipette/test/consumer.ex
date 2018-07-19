defmodule Pipette.Test.Consumer do
  @moduledoc false

  use Pipette.GenStage, stage_type: :consumer

  alias Pipette.IP

  defstruct test_controller_pid: nil

  def init(block) do
    state = %{
      block: block,
      buckets: %{},
      events: [],
      subscriptions: %{}
    }

    {:consumer, state}
  end

  def handle_events(
        [ip],
        {pid, _},
        %{block: block, buckets: buckets, events: events, subscriptions: subscriptions} = state
      ) do
    controller = GenServer.call(block.test_controller_pid, :get_controller)
    {stage_id, _block} = GenServer.call(controller, {:get_stage, pid})

    subscriptions =
      case Map.get(subscriptions, stage_id) do
        nil ->
          subscriptions

        reply_to when is_pid(reply_to) ->
          send(reply_to, {:fetch_response, ip})
          Map.delete(subscriptions, stage_id)
      end

    buckets = Map.put(buckets, stage_id, ip)
    events = [ip | events]
    new_state = %{state | buckets: buckets, events: events, subscriptions: subscriptions}

    {:noreply, [], new_state}
  end

  def handle_cast(
        {:fetch, stage_id, reply_to},
        %{buckets: buckets, subscriptions: subscriptions} = state
      ) do
    case Map.get(buckets, stage_id) do
      nil ->
        subscriptions = Map.put(subscriptions, stage_id, reply_to)
        new_state = %{state | subscriptions: subscriptions}
        {:noreply, [], new_state}

      %IP{} = ip ->
        send(reply_to, {:fetch_response, ip})
        {:noreply, [], state}
    end
  end

  def handle_call(:events, _from, %{events: events} = state) do
    {:reply, Enum.reverse(events), [], state}
  end
end
