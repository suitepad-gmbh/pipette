defmodule Pipette.Test do
  @moduledoc """
  This module can be used in a test case and provides convenience functions to
  handle recipes in tests.

  Using it imports the functions defined on `Pipette.Test`.

  ## Example

      defmodule AddOneTest do
        use ExUnit.Case
        use Pipette.Test

        test "recipe should add 1 to the input value" do
          assert run_recipe(AddOne.recipe(), 3) == 4
        end
      end

  """

  defmacro __using__(_) do
    quote do
      import Pipette.Test
    end
  end

  @doc """
  Starts a recipe test controller and returns its pid.

  This function injects a special `:__TEST_CONSUMER__` stage that is collecting events on each stage,
  and replying to subscriptions setup within tests. See `Pipette.Test.events/1` and `Pipette.Test.await/1`.

  It is safe to use for recipes following a standard `Pipette.Client` protocol with `:IN` / `:OUT` stages.
  All recipes that setup proper consumer / sink stages, for all their branches of execution, can be tested
  with `Pipette.Test.load_recipe/2`.

  ## A word of caution

  The `:__TEST_CONSUMER__` is creating demand on each stage. This incurs a slight change in behaviour, and
  particular care should be taken when creating recipes that do not follow the standard `:IN` / `:OUT` protocol.

  **Missing demand will break recipes, or branches of execution**. If your recipe is built out of
  producer or producer/consumer stages but they have no consumer/sink subscribed to them,
  the test might pass, but the recipe when started outside tests will not succeed.

  **TODO: This is a limitation, that should be implemented as a warning/error in future versions.**

  For such recipes and tests, always start an actual `Pipette.Client`, and test for the expected side effects.

  Make sure you actually create demand on all branches of execution, either by using `Pipette.Stage.Consumer` or `Pipette.Stage.Sink`.
  """
  def load_recipe(recipe_or_module, args \\ [])

  def load_recipe(%Pipette.Recipe{} = recipe, args) do
    Pipette.Test.Controller.start(recipe, args)
  end

  def load_recipe(module, args) when is_atom(module) do
    load_recipe(module.recipe(), args)
  end

  @doc """
  Pushes a message on a stage (default: `:IN`).
  """
  def push(controller_pid, value, inlet \\ :IN) when is_pid(controller_pid) do
    Pipette.Test.Controller.push(controller_pid, value, inlet)
  end

  @doc """
  Blocks for one IP from the given stage (default: `:OUT`).

  Can only be used if the recipe was started with `Pipette.Test.load_recipe/2`.
  """
  def await(controller_pid, outlet \\ :OUT, opts \\ []) when is_pid(controller_pid) do
    Pipette.Test.Controller.await(controller_pid, outlet, opts)
  end

  @doc """
  Blocks for one value from the given stage (default: `:OUT`).

  Can only be used if the recipe was started with `Pipette.Test.load_recipe/2`.
  """
  def await_value(controller_pid, outlet \\ :OUT, opts \\ []) when is_pid(controller_pid) do
    %Pipette.IP{value: value} = await(controller_pid, outlet, opts)
    value
  end

  @doc """
  Runs the whole recipe with the given value on `:IN`, waiting for one value from the given stage (default: `:OUT`).
  """
  def run_recipe(recipe_pid_or_module, value, outlet \\ :OUT, opts \\ [])

  def run_recipe(pid, value, outlet, opts) when is_pid(pid) do
    pid
    |> push(value)
    |> await_value(outlet, opts)
  end

  def run_recipe(module, value, outlet, opts) do
    module
    |> load_recipe
    |> run_recipe(value, outlet, opts)
  end

  @doc """
  Returns all events mapped by label, gathered from a recipe started with a test consumer.

  Can only be used if the recipe was started with `Pipette.Test.load_recipe/2`.
  """
  def events(test_controller_pid) do
    Pipette.Test.Controller.events(test_controller_pid)
  end
end
