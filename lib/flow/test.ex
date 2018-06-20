defmodule Flow.Test do
  @moduledoc """
  This module can be used in a test case and provides convenience functions to
  handle patterns in tests.

  Example

      defmodule FooTest do
        use ExUnit.Case
        use Flow.Test

        test "pattern should add 1 to the input value" do
          assert run_pattern(AddOne.pattern(), 3) == 4
        end
      end

  """

  defmacro __using__(_) do
    quote do
      import Flow.Test
    end
  end

  def load_pattern(pattern) do
    Flow.Test.Controller.start(pattern)
  end

  def push(controller_pid, value) do
    Flow.Test.Controller.push(controller_pid, value)
  end

  def await(controller_pid, outlet \\ :OUT) do
    Flow.Test.Controller.await(controller_pid, outlet)
  end

  def await_value(controller_pid, outlet \\ :OUT) do
    %Flow.IP{value: value} = await(controller_pid, outlet)
    value
  end

  def run_pattern(pattern_or_pid, value, outlet \\ :OUT)

  def run_pattern(%Flow.Pattern{} = pattern, value, outlet) do
    pattern
    |> load_pattern
    |> run_pattern(value, outlet)
  end

  def run_pattern(pid, value, outlet) when is_pid(pid) do
    pid
    |> push(value)
    |> await_value(outlet)
  end
end
