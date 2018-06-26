defmodule Pipette.TestTest do
  use ExUnit.Case
  use Pipette.Test

  alias Pipette.IP

  defmodule FooBarRecipe do
    use Pipette.Recipe

    def stages,
      do: %{
        foo: %Pipette.Stage{
          handler: fn
            "foo" -> "bar"
            val -> val
          end
        }
      }

    def subscriptions,
      do: [
        {:foo, :IN},
        {:OUT, :foo}
      ]
  end

  test "#load_recipe starts a test recipe controller" do
    pid = load_recipe(FooBarRecipe.recipe())
    assert is_pid(pid)
    assert Process.alive?(pid)
  end

  test "#push pushes a message onto IN of the recipe" do
    pid = load_recipe(FooBarRecipe.recipe())
    push(pid, "foo")
    assert await_value(pid, :IN) == "foo"
  end

  test "#await_value waits for a message on OUT" do
    assert "bar" ==
             load_recipe(FooBarRecipe.recipe())
             |> push("foo")
             |> await_value()
  end

  test "#await waits for a message and returns the IP" do
    assert %IP{value: "bar"} =
             load_recipe(FooBarRecipe.recipe())
             |> push("foo")
             |> await()

    assert %IP{value: "foo"} =
             load_recipe(FooBarRecipe.recipe())
             |> push("foo")
             |> await(:IN)
  end

  test "#run_recipe starts a recipe, puts a message on IN and awaits OUT" do
    assert "bar" == run_recipe(FooBarRecipe.recipe(), "foo")
  end

  test "#run_recipe starts a recipe, puts a message on IN and awaits on a given stage" do
    assert "foo" == run_recipe(FooBarRecipe.recipe(), "foo", :IN)
  end

  test "#run_recipe puts a message on IN and awaits the result for a started recipe" do
    assert "bar" ==
             load_recipe(FooBarRecipe.recipe())
             |> run_recipe("foo")

    assert "foo" ==
             load_recipe(FooBarRecipe.recipe())
             |> run_recipe("foo", :IN)
  end

  test "#run_recipe takes an atom and and starts the defined recipe" do
    assert "foo" == run_recipe(FooBarRecipe, "foo", :IN)
  end
end
