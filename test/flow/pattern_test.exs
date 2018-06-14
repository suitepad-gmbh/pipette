defmodule Flow.PatternTest do
  use ExUnit.Case

  alias Flow.Pattern
  alias Flow.Block

  defmodule DefaultPattern do
    use Flow.Pattern
  end

  defmodule RegisteredPattern do
    use Flow.Pattern

    def process_name do
      {:via, Registry, {Registry.ViaTest, :registered}}
    end

    def blocks,
      do: %{
        add_one: %Block{fun: &(&1 + 1)}
      }

    def subscriptions,
      do: [
        {:add_one, :IN},
        {:OUT, :add_one}
      ]
  end

  defmodule FooToBarPattern do
    use Flow.Pattern

    def blocks,
      do: %{
        foo_to_bar: %Block{
          fun: fn
            "foo" -> "bar"
            other -> other
          end
        },
        zig_to_zag: %Block{
          fun: fn
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

  test "#start_link starts a controlled pattern" do
    {:ok, pid} = FooToBarPattern.start_link()
    Process.unlink(pid)
    stage1 = Pattern.Controller.get_stage(pid, :foo_to_bar)
    stage2 = Pattern.Controller.get_stage(pid, :zig_to_zag)

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

  test "start a pattern controller with a process registry" do
    {:ok, _reg} = Registry.start_link(keys: :unique, name: Registry.ViaTest)
    {:ok, _pid} = RegisteredPattern.start_link()

    client = Flow.Client.start(RegisteredPattern.pattern().id)
    assert 1 == Flow.Client.call!(client, 0)
  end

  test "#process_name returns the module by default" do
    assert DefaultPattern == DefaultPattern.process_name()
  end

  test "#process_name returns the overwrite if given" do
    assert {:via, Registry, {Registry.ViaTest, :registered}} == RegisteredPattern.process_name()
  end
end
