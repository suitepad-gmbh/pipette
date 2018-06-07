defmodule Flow.PatternTest do
  use ExUnit.Case

  alias Flow.Pattern
  alias Flow.Block

  defmodule FooToBarPattern do
    use Flow.Pattern

    def blocks, do: %{
      foo_to_bar: %Block{fun: fn
        "foo" -> "bar"
        other -> other
      end},
      zig_to_zag: %Block{fun: fn
        "zig" -> "zag"
        other -> other
      end}
    }

    def subscriptions, do: [
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
    after 1000 ->
      assert false
    end
  end

end

