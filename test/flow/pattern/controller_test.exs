defmodule Flow.Pattern.ControllerTest do
  use ExUnit.Case

  alias Flow.Pattern
  alias Flow.Pattern.Controller
  alias Flow.Client
  alias Flow.Block

  test "subscribe to all routes of a stage at once" do
    client =
      Pattern.new(%{
        id: __MODULE__,
        blocks: %{
          foo: %Block{fun: fn value -> {value, "message"} end}
        },
        subscriptions: [
          {:foo, :IN},
          {:OUT, {:foo, :*}}
        ]
      })
      |> Pattern.start_controller()
      |> Client.start()

    assert {:ok, "message"} == Client.call(client, :ok)
    assert {:ok, "message"} == Client.call(client, :foo)
    assert {:ok, "message"} == Client.call(client, :bar)
  end

  test "subscribe to all stages of a pattern at once" do
    pid =
      Pattern.new(%{
        id: __MODULE__,
        blocks: %{
          IN: %Block.PushProducer{},
          foo: %Block{fun: fn _ -> "foo" end},
          bar: %Block{fun: fn _ -> "bar" end},
          pass: %Block{fun: fn v -> v end}
        },
        subscriptions: [
          {:foo, :IN},
          {:bar, :IN},
          {:pass, :*}
        ]
      })
      |> Pattern.start_controller()

    client = Client.start(pid)

    out = Controller.get_stage(pid, :pass)
    stream = GenStage.stream([{out, max_demand: 1}])

    task =
      Task.async(fn ->
        Stream.take(stream, 3)
        |> Enum.into([])
      end)

    Client.push(client, "IN")

    assert [
             %Flow.IP{value: "IN"},
             %Flow.IP{value: "bar"},
             %Flow.IP{value: "foo"}
           ] = Task.await(task)
  end

  test "subscribe to all stages and routes of a pattern at once" do
    pid =
      Pattern.new(%{
        id: __MODULE__,
        blocks: %{
          IN: %Block.PushProducer{},
          foo: %Block{fun: fn _ -> "foo" end},
          route: %Block{fun: fn route -> {route, "route"} end},
          pass: %Block.Passthrough{}
        },
        subscriptions: [
          {:foo, :IN},
          {:route, :IN},
          {:pass, {:*, :*}}
        ]
      })
      |> Pattern.start_controller()

    client = Client.start(pid)

    out = Controller.get_stage(pid, :pass)
    stream = GenStage.stream([{out, max_demand: 1}])

    task =
      Task.async(fn ->
        Stream.take(stream, 3)
        |> Enum.into([])
      end)

    Client.push(client, :foo)

    assert [
             %Flow.IP{value: :foo, route: :ok},
             %Flow.IP{value: "route", route: :foo},
             %Flow.IP{value: "foo", route: :ok}
           ] = Task.await(task)
  end

  test "subscribe to all stages with a specific route of a pattern at once" do
    pid =
      Pattern.new(%{
        id: __MODULE__,
        blocks: %{
          IN: %Block.PushProducer{},
          foo: %Block{fun: fn _ -> "foo" end},
          route: %Block{fun: fn route -> {route, "route"} end},
          pass: %Block.Passthrough{}
        },
        subscriptions: [
          {:foo, :IN},
          {:route, :IN},
          {:pass, {:*, :error}}
        ]
      })
      |> Pattern.start_controller()

    client = Client.start(pid)

    out = Controller.get_stage(pid, :pass)
    stream = GenStage.stream([{out, max_demand: 1}])

    task =
      Task.async(fn ->
        Stream.take(stream, 1)
        |> Enum.into([])
      end)

    Client.push(client, :error)

    assert [
             %Flow.IP{value: "route", route: :error}
           ] = Task.await(task)
  end
end
