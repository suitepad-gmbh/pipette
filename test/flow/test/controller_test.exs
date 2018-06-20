defmodule Flow.Test.ControllerTest do
  use ExUnit.Case
  alias Flow.IP

  def pattern() do
    Flow.Pattern.new(%{
      id: __MODULE__,
      blocks: %{
        foo: %Flow.Block{
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
      pattern()
      |> Flow.Test.Controller.start()
      |> Flow.Test.Controller.push("foo")
      |> Flow.Test.Controller.await()

    assert %IP{value: "bar"} = result
  end

  test "#awaits for results from a given block" do
    cont =
      pattern()
      |> Flow.Test.Controller.start()
      |> Flow.Test.Controller.push("foo")

    assert %IP{value: "foo"} = Flow.Test.Controller.await(cont, :IN)
    assert %IP{value: "bar"} = Flow.Test.Controller.await(cont, :foo)
  end

  test "#events returns intermediate results for each stage after an await" do
    cont =
      pattern()
      |> Flow.Test.Controller.start()
      |> Flow.Test.Controller.push("foo")

    Flow.Test.Controller.await(cont)

    assert [%IP{value: "foo"}, %IP{value: "bar"}, %IP{value: "bar"}] =
             Flow.Test.Controller.events(cont)
  end

  test "#await waits for data on :OUT" do
    pattern =
      Flow.Pattern.new(%{
        id: __MODULE__,
        blocks: %{
          sleep: %Flow.Block{
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
      pattern
      |> Flow.Test.Controller.start()
      |> Flow.Test.Controller.push("Peter")
      |> Flow.Test.Controller.await()

    assert %IP{value: "Peter slept well"} = result
  end
end
