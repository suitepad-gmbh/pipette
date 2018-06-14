defmodule Flow.ClientTest do
  use ExUnit.Case

  alias Flow.Pattern
  alias Flow.Block
  alias Flow.Client

  setup_all do
    pid =
      Pattern.new(%{
        id: __MODULE__,
        blocks: %{
          transform: %Block{
            fun: fn
              "foo" -> "bar"
              "zig" -> "zag"
              fun when is_function(fun) -> fun.()
            end
          }
        },
        subscriptions: [
          {:transform, :IN},
          {:OUT, :transform}
        ]
      })
      |> Pattern.start_controller()

    {:ok, _pid} = Client.start_link(pid, name: :our_client)
    :ok
  end

  test "#call! pushes a messages on IN and waits for the response on OUT" do
    assert "bar" == Client.call!(:our_client, "foo")
  end

  test "#call pushes a messages on IN and waits for the response on OUT" do
    assert {:ok, "bar"} == Client.call(:our_client, "foo")
  end

  test "#call with timeout" do
    assert false
    # TODO:
    #
    #   The client awaits messages with its own PID set to reply_to.
    #
    #   In fact, it must await messages for itself
    #   AND messages that are tagged uniquely with that :call request.
    #
    assert {
             :error,
             %Client.TimeoutError{}
           } = Client.call(:our_client, fn -> :timer.sleep(1000) end, 50)
  end

  # test "#pull demands a messages from OUT of the pattern" do
  #   :ok = Client.push(:our_client, "zig")
  #   assert "zag" == Client.pull(:our_client, :OUT)
  # end
end
