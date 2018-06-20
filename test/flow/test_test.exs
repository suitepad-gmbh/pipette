defmodule Flow.TestTest do
  use ExUnit.Case
  use Flow.Test

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

  test "#load_pattern starts a test pattern controller" do
    pid = load_pattern(pattern())
    assert is_pid(pid)
    assert Process.alive?(pid)
  end

  test "#push pushes a message onto IN of the pattern" do
    pid = load_pattern(pattern())
    push(pid, "foo")
    assert await_value(pid, :IN) == "foo"
  end

  test "#await_value waits for a message on OUT" do
    assert "bar" ==
             load_pattern(pattern())
             |> push("foo")
             |> await_value()
  end

  test "#await waits for a message and returns the IP" do
    assert %IP{value: "bar"} ==
             load_pattern(pattern())
             |> push("foo")
             |> await()

    assert %IP{value: "foo"} ==
             load_pattern(pattern())
             |> push("foo")
             |> await(:IN)
  end

  test "#run_pattern starts a pattern, puts a message on IN and awaits OUT" do
    assert "bar" == run_pattern(pattern(), "foo")
  end

  test "#run_pattern starts a pattern, puts a message on IN and awaits on a given stage" do
    assert "foo" == run_pattern(pattern(), "foo", :IN)
  end

  test "#run_pattern puts a message on IN and awaits the result for a started pattern" do
    assert "bar" ==
             load_pattern(pattern())
             |> run_pattern("foo")

    assert "foo" ==
             load_pattern(pattern())
             |> run_pattern("foo", :IN)
  end
end
