defmodule Pipette.RecipeTest do
  use ExUnit.Case

  alias Pipette.Stage
  alias Pipette.Controller

  defmodule DefaultRecipe do
    use Pipette.Recipe
  end

  defmodule RegisteredRecipe do
    use Pipette.Recipe

    def process_name do
      {:via, Registry, {Registry.ViaTest, :registered}}
    end

    def stages,
      do: %{
        add_one: %Stage{handler: &(&1 + 1)}
      }

    def subscriptions,
      do: [
        {:add_one, :IN},
        {:OUT, :add_one}
      ]
  end

  defmodule FooToBarRecipe do
    use Pipette.Recipe

    def stages,
      do: %{
        foo_to_bar: %Stage{
          handler: fn
            "foo" -> "bar"
            other -> other
          end
        },
        zig_to_zag: %Stage{
          handler: fn
            "zig" -> "zag"
            other -> other
          end
        }
      }

    def subscriptions,
      do: [
        {:foo_to_bar, :IN},
        {:zig_to_zag, :foo_to_bar},
        {:OUT, :zig_to_zag}
      ]
  end

  test "#start_link starts a controlled recipe" do
    {:ok, pid} = FooToBarRecipe.start_link()
    Process.unlink(pid)
    stage1 = Controller.get_stage_pid(pid, :foo_to_bar)
    stage2 = Controller.get_stage_pid(pid, :zig_to_zag)

    ref = Process.monitor(pid)
    Process.exit(stage2, :kill)

    receive do
      {:DOWN, ^ref, _, _, _} ->
        assert Process.alive?(pid) == false
        assert Process.alive?(stage1) == false
        assert Process.alive?(stage2) == false
    after
      1000 ->
        assert false
    end
  end

  test "start a recipe controller with a process registry" do
    {:ok, _reg} = Registry.start_link(keys: :unique, name: Registry.ViaTest)
    {:ok, _pid} = RegisteredRecipe.start_link()

    client = Pipette.Client.start(RegisteredRecipe.recipe().id)
    assert 1 == Pipette.Client.call!(client, 0)
  end

  test "#process_name returns the module by default" do
    assert DefaultRecipe == DefaultRecipe.process_name()
  end

  test "#process_name returns the overwrite if given" do
    assert {:via, Registry, {Registry.ViaTest, :registered}} == RegisteredRecipe.process_name()
  end
end
