defmodule Pipette.ControllerTest do
  use ExUnit.Case

  alias Pipette.Recipe
  alias Pipette.Controller
  alias Pipette.Client
  alias Pipette.Stage

  test "subscribe to all routes of a stage at once" do
    client =
      Recipe.new(%{
        id: __MODULE__,
        stages: %{
          foo: %Stage{fun: fn value -> {value, "message"} end}
        },
        subscriptions: [
          {:foo, :IN},
          {:OUT, {:foo, :*}}
        ]
      })
      |> Recipe.start_controller()
      |> Client.start()

    assert {:ok, "message"} == Client.call(client, :ok)
    assert {:ok, "message"} == Client.call(client, :foo)
    assert {:ok, "message"} == Client.call(client, :bar)
  end

  test "subscribe to all stages of a recipe at once" do
    pid =
      Recipe.new(%{
        id: __MODULE__,
        stages: %{
          IN: %Stage.PushProducer{},
          foo: %Stage{fun: fn _ -> "foo" end},
          bar: %Stage{fun: fn _ -> "bar" end},
          pass: %Stage{fun: fn v -> v end}
        },
        subscriptions: [
          {:foo, :IN},
          {:bar, :IN},
          {:pass, :*}
        ]
      })
      |> Recipe.start_controller()

    client = Client.start(pid)

    out = Controller.get_stage_pid(pid, :pass)
    stream = GenStage.stream([{out, max_demand: 1}])

    task =
      Task.async(fn ->
        Stream.take(stream, 3)
        |> Enum.into([])
      end)

    Client.push(client, "IN")

    assert [
             %Pipette.IP{value: "IN"},
             %Pipette.IP{value: "bar"},
             %Pipette.IP{value: "foo"}
           ] = Task.await(task)
  end

  test "subscribe to all stages and routes of a recipe at once" do
    pid =
      Recipe.new(%{
        id: __MODULE__,
        stages: %{
          IN: %Stage.PushProducer{},
          foo: %Stage{fun: fn _ -> "foo" end},
          route: %Stage{fun: fn route -> {route, "route"} end},
          pass: %Stage.Passthrough{}
        },
        subscriptions: [
          {:foo, :IN},
          {:route, :IN},
          {:pass, {:*, :*}}
        ]
      })
      |> Recipe.start_controller()

    client = Client.start(pid)

    out = Controller.get_stage_pid(pid, :pass)
    stream = GenStage.stream([{out, max_demand: 1}])

    task =
      Task.async(fn ->
        Stream.take(stream, 3)
        |> Enum.into([])
      end)

    Client.push(client, :foo)

    assert [
             %Pipette.IP{value: :foo, route: :ok},
             %Pipette.IP{value: "route", route: :foo},
             %Pipette.IP{value: "foo", route: :ok}
           ] = Task.await(task)
  end

  test "subscribe to all stages with a specific route of a recipe at once" do
    pid =
      Recipe.new(%{
        id: __MODULE__,
        stages: %{
          IN: %Stage.PushProducer{},
          foo: %Stage{fun: fn _ -> "foo" end},
          route: %Stage{fun: fn route -> {route, "route"} end},
          pass: %Stage.Passthrough{}
        },
        subscriptions: [
          {:foo, :IN},
          {:route, :IN},
          {:pass, {:*, :error}}
        ]
      })
      |> Recipe.start_controller()

    client = Client.start(pid)

    out = Controller.get_stage_pid(pid, :pass)
    stream = GenStage.stream([{out, max_demand: 1}])

    task =
      Task.async(fn ->
        Stream.take(stream, 1)
        |> Enum.into([])
      end)

    Client.push(client, :error)

    assert [
             %Pipette.IP{value: "route", route: :error}
           ] = Task.await(task)
  end
end
