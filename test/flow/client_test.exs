defmodule Flow.ClientTest do
  use ExUnit.Case

  alias Flow.Pattern
  alias Flow.Block
  alias Flow.Client

  setup_all do
    pattern = Pattern.new(%{
      blocks: %{
        transform: %Block{fun: fn
          "foo" -> "bar"
          "zig" -> "zag"
        end}
      },
      subscriptions: [
        {:transform, :IN},
        {:OUT, :transform}
      ]
    }) |> Pattern.start
    {:ok, _pid} = Client.start_link(pattern, name: :our_client)
    :ok
  end

  test "#call pushes a messages on IN and waits for the response on OUT" do
    assert "bar" == Client.call(:our_client, "foo")
  end

  # test "#pull demands a messages from OUT of the pattern" do
  #   :ok = Client.push(:our_client, "zig")
  #   assert "zag" == Client.pull(:our_client, :OUT)
  # end

end

