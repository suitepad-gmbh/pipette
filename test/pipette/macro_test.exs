defmodule Pipette.MacroTest do
  use ExUnit.Case
  use Pipette.Test

  defmodule TestModule do
    use Pipette.OnDefinition

    @subscribe foo: :IN
    @subscribe OUT: {:foo, :*}

    def foo("foo"), do: "bar"

    def foo("err"), do: {:error, "err"}

    def foo(num) when is_number(num), do: to_string(num)

    def foo(val), do: val

    def foo(), do: private()

    defp private, do: "do not list me"
  end

  test "TestModule" do
    assert "bar" == TestModule.foo("foo")
    assert {:error, "err"} == TestModule.foo("err")
    assert "123" == TestModule.foo(123)
    assert "123" == TestModule.foo(123)
  end

  test "@subscribe accumulates subscriptions" do
    assert [
      {:foo, :IN},
      {:OUT, {:foo, :*}}
    ] == TestModule.subscriptions()
  end

  test "stages returns all public functions of the module, defined after use Pipette.Recipe" do
    assert %{
      foo: %Pipette.Stage{handler: {TestModule, :foo, []}}
    } == TestModule.stages()
  end

  test "TestModule represents a fully functional recipe" do
    controller = load_recipe(TestModule)
    assert "bar" == run_recipe controller, "foo"
    assert "foo" == run_recipe controller, "foo", :IN
    assert %Pipette.IP{route: :error, value: "err"} = controller
                                                      |> push("err")
                                                      |> await()
  end

end
