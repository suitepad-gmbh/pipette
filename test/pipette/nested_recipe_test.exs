defmodule Pipette.NestedRecipeTest do
  use ExUnit.Case
  use Pipette.Test

  alias Pipette.Recipe
  alias Pipette.Stage
  alias Pipette.Client
  alias Pipette.IP

  test "nest other recipes with Stage.Recipe" do
    foo_recipe = Recipe.new(%{
      stages: %{
        foo: %Stage{handler: fn
          "foo" -> "bar"
          val -> val
        end}
      },
      subscriptions: [
        {:foo, :IN},
        {:OUT, :foo}
      ]
    })

    string_length = Recipe.new(%{
      stages: %{
        inner: %Stage.Recipe{recipe: foo_recipe},
        len: %Stage{handler: fn val -> {val, String.length(val)} end}
      },
      subscriptions: [
        {:inner, :IN},
        {:len, :inner},
        {:OUT, :len}
      ]
    })

    assert {"bar", 3} = run_recipe(string_length, "bar")
  end

  test "nest multiple of the same recipe within each other" do
    add_one = Recipe.new(%{
      id: :one,
      stages: %{
        one: %Stage{handler: fn val -> val + 1 end}
      },
      subscriptions: [
        {:one, :IN},
        {:OUT, :one}
      ]
    })
    add_two = Recipe.new(%{
      id: :two,
      stages: %{
        one: %Stage.Recipe{recipe: add_one},
        two: %Stage.Recipe{recipe: add_one}
      },
      subscriptions: [
        {:one, :IN},
        {:two, :one},
        {:OUT, :two}
      ]
    })
    add_three = Recipe.new(%{
      id: :three,
      stages: %{
        two: %Stage.Recipe{recipe: add_two},
        three: %Stage.Recipe{recipe: add_one}
      },
      subscriptions: [
        {:two, :IN},
        {:three, :two},
        {:OUT, :three}
      ]
    })

    assert 3 == run_recipe(add_three, 0)
  end

  test "break a nested recipe on timeout" do
    nested = Recipe.new(%{
      stages: %{
        fun: %Stage{handler: fn -> :timer.sleep(100) end}
      },
      subscriptions: [
        {:fun, :IN},
        {:OUT, :fun}
      ]
    })
    recipe = Recipe.new(%{
      stages: %{
        nested: %Stage.Recipe{recipe: nested, timeout: 50}
      },
      subscriptions: [
        {:nested, :IN},
        {:OUT, {:nested, :*}}
      ]
    })
    assert %IP{route: :error, value: %Client.TimeoutError{}} =
      load_recipe(recipe)
      |> push("foo")
      |> await()
  end
end

