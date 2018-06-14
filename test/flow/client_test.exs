defmodule Flow.ClientTest do
  use ExUnit.Case

  alias Flow.Pattern
  alias Flow.Block
  alias Flow.Client

  setup do
    controller = Pattern.new(%{
      id: __MODULE__,
      blocks: %{
        foo2bar: %Block{fun: fn val -> String.replace(val, "foo", "bar") end},
        zig2zag: %Block{fun: fn val -> String.replace(val, "zig", "zag") end}
      },
      subscriptions: [
        {:foo2bar, :IN},
        {:zig2zag, :foo2bar},
        {:OUT, :zig2zag}
      ]
    }) |> Pattern.start_controller
    client = Client.start(controller)
    {:ok, %{client: client, controller: controller}}
  end

  test "#call! pushes a messages on IN and waits for the response on OUT", %{client: client} do
    assert "bar" == Client.call!(client, "foo")
  end

  test "#call pushes a messages on IN and waits for the response on OUT", %{client: client} do
    assert {:ok, "bar"} == Client.call(client, "foo")
  end

  # test "#call with timeout" do
  #   assert false
  #   # TODO:
  #   #
  #   #   The client awaits messages with its own PID set to reply_to.
  #   #
  #   #   In fact, it must await messages for itself
  #   #   AND messages that are tagged uniquely with that :call request.
  #   #
  #   assert {
  #     :error, %Client.TimeoutError{}
  #   } = Client.call(:our_client, fn -> :timer.sleep(1000) end, 50)
  # end

  test "#push sends a value into the pattern", %{client: client, controller: controller} do
    task = Task.async(fn -> Client.pull(client, :zig2zag) end)
    :timer.sleep(10)
    Client.start(controller)
    |> Client.push("zig", to: :foo2bar)
    assert Task.await(task) == "zag"
  end
end
