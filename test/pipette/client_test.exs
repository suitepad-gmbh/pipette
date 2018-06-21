defmodule Pipette.ClientTest do
  use ExUnit.Case

  alias Pipette.Recipe
  alias Pipette.Stage
  alias Pipette.Client
  alias Pipette.Controller

  setup do
    controller =
      Recipe.new(%{
        id: __MODULE__,
        stages: %{
          block: %Stage{
            fun: fn
              "foo" -> "bar"
              val when is_function(val) -> val.()
              val -> val
            end
          }
        },
        subscriptions: [
          {:block, :IN},
          {:OUT, :block}
        ]
      })
      |> Recipe.start_controller()

    client = Client.start(controller)
    {:ok, %{client: client, controller: controller}}
  end

  test "#call! pushes a messages on IN and waits for the response on OUT", %{client: client} do
    assert "bar" == Client.call!(client, "foo")
  end

  test "#call pushes a messages on IN and waits for the response on OUT", %{client: client} do
    assert {:ok, "bar"} == Client.call(client, "foo")
  end

  test "#call with timeout", %{client: client} do
    assert {
             :error,
             %Client.TimeoutError{}
           } = Client.call(client, fn -> :timer.sleep(1000) end, 50)
  end

  test "#pull demands messages out of a recipe", %{client: client, controller: controller} do
    Task.async(fn ->
      # lets wait shortly for the pull to be established
      :timer.sleep(50)
      pid = Client.start(controller)
      :ok = Client.push(pid, "foo")
    end)

    assert "bar" == Client.pull(client, :block)
  end

  test "#push sends a value into the recipe", %{client: client, controller: controller} do
    stage = Controller.get_stage_pid(controller, :block)

    task =
      Task.async(fn ->
        %Pipette.IP{value: value} =
          GenStage.stream([{stage, max_demand: 1}])
          |> Stream.take(1)
          |> Enum.to_list()
          |> List.first()

        value
      end)

    # lets wait shortly for the GenStage subscription to be established
    :timer.sleep(50)

    Client.push(client, "foo", to: :block)

    assert "bar" == Task.await(task)
  end

  test "#call waits for the right message, dismissing everything in between", %{client: client} do
    fun = fn ->
      :timer.sleep(100)
      "times out"
    end

    # this call will timeout, leaving this message in the Client inbox
    assert {:error, _} = Client.call(client, fun, 50)
    # this message will pass through, skipping the message that was left in the inbox
    assert {:ok, "bar"} == Client.call(client, "foo")
  end
end
