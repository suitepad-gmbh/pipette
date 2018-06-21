defmodule Pipette.Test.ControllerTest do
  use ExUnit.Case
  alias Pipette.IP

  def recipe() do
    Pipette.Recipe.new(%{
      id: __MODULE__,
      stages: %{
        foo: %Pipette.Stage{
          fun: fn
            "foo" -> "bar"
            val -> val
          end
        }
      },
      subscriptions: [
        {:foo, :IN},
        {:OUT, :foo}
      ]
    })
  end

  test "#await receive data from :OUT" do
    result =
      recipe()
      |> Pipette.Test.Controller.start()
      |> Pipette.Test.Controller.push("foo")
      |> Pipette.Test.Controller.await()

    assert %IP{value: "bar"} = result
  end

  test "#awaits for results from a given block" do
    cont =
      recipe()
      |> Pipette.Test.Controller.start()
      |> Pipette.Test.Controller.push("foo")

    assert %IP{value: "foo"} = Pipette.Test.Controller.await(cont, :IN)
    assert %IP{value: "bar"} = Pipette.Test.Controller.await(cont, :foo)
  end

  test "#events returns intermediate results for each stage after an await" do
    cont =
      recipe()
      |> Pipette.Test.Controller.start()
      |> Pipette.Test.Controller.push("foo")

    Pipette.Test.Controller.await(cont)

    assert [%IP{value: "foo"}, %IP{value: "bar"}, %IP{value: "bar"}] =
             Pipette.Test.Controller.events(cont)
  end

  test "#await waits for data on :OUT" do
    recipe =
      Pipette.Recipe.new(%{
        id: __MODULE__,
        stages: %{
          sleep: %Pipette.Stage{
            fun: fn val ->
              :timer.sleep(300)
              "#{val} slept well"
            end
          }
        },
        subscriptions: [
          {:sleep, :IN},
          {:OUT, :sleep}
        ]
      })

    result =
      recipe
      |> Pipette.Test.Controller.start()
      |> Pipette.Test.Controller.push("Peter")
      |> Pipette.Test.Controller.await()

    assert %IP{value: "Peter slept well"} = result
  end
end
