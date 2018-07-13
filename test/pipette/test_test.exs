defmodule Pipette.TestTest do
  use ExUnit.Case
  use Pipette.Test

  alias Pipette.IP

  defmodule CustomProducer do
    use Pipette.GenStage, stage_type: :producer

    defstruct handler: {__MODULE__, :add_one}

    def handle_cast(%Pipette.IP{} = ip, %__MODULE__{handler: handler} = stage) do
      new_ip = Pipette.Handler.handle(handler, ip)
      {:noreply, [new_ip], stage}
    end

    def handle_demand(_demand, block) do
      {:noreply, [], block}
    end

    def add_one(value), do: value + 1
  end

  defmodule FooBarRecipe do
    use Pipette.Recipe

    @stage foo: %Pipette.Stage{
             handler: fn
               "foo" -> "bar"
               val -> val
             end
           }
    @subscribe foo: :IN
    @subscribe OUT: :foo
  end

  defmodule CustomProducerRecipe do
    use Pipette.Recipe

    @stage IN: %CustomProducer{}
    @subscribe OUT: :IN
  end

  test "#load_recipe starts a test recipe controller" do
    pid = load_recipe(FooBarRecipe.recipe())
    assert is_pid(pid)
    assert Process.alive?(pid)
  end

  test "#load_recipe can keep the original producer" do
    pid = load_recipe(CustomProducerRecipe, keep_producer: true)
    assert is_pid(pid)
    assert Process.alive?(pid)
    push(pid, 1)
    assert await_value(pid, :IN) == 2
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

  test "#run_recipe takes a module and starts the defined recipe" do
    assert "bar" == run_recipe(FooBarRecipe, "foo")
  end
end
