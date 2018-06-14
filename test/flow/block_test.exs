defmodule Flow.BlockTest do
  use ExUnit.Case

  defmodule Test do
    def add(value, args \\ 0) do
      value + args
    end
  end

  alias Flow.Block
  alias Flow.BlockTest.Test
  alias Flow.Pattern
  alias Flow.Client

  test "#perform calls into a module and the given function" do
    assert Block.perform(%Block{module: List, function: :first}, %Flow.IP{value: [1, 2, 3]}) == 1
    assert Block.perform(%Block{module: Test, function: :add, args: 1}, %Flow.IP{value: 2}) == 3
    assert Block.perform(%Block{module: Test, function: :add, args: nil}, %Flow.IP{value: 2}) == 2
  end

  test "handles cast, executes the block and continues the pattern from there" do
    client =
      Pattern.new(%{
        id: __MODULE__,
        blocks: %{
          add1: %Block{module: Test, function: :add, args: 1},
          add2: %Block{module: Test, function: :add, args: 2}
        },
        subscriptions: [
          {:add2, :add1}
        ]
      })
      |> Pattern.start_controller()
      |> Client.start()

    task = Task.async(fn -> Client.pull(client, :add2) end)
    Client.push(client, 0, to: :add1)
    assert Task.await(task) == 3
  end

  # test "hey, we could do routing this these" do
  #   pattern = %Pattern{
  #     blocks: [
  #       %Block.Producer{id: :generator, type: :producer, stream: Stream.iterate(1, &(&1 + 1))},
  #       %Block{id: :divide_and_conquer, fun: fn
  #         n when rem(n, 2) == 0 -> {:even, n}
  #         n when rem(n, 2) != 0 -> {:odd, n}
  #       end},
  #       %Block{id: :make_even, fun: &({:even, &1 + 1})},
  #       %Block{id: :pass_even, fun: &({:even, &1})}
  #     ],
  #     subscriptions: [
  #       {:divide_and_conquer, :generator},
  #       {:make_even, {:divide_and_conquer, :odd}},
  #       {:pass_even, {:divide_and_conquer, :even}}
  #     ]
  #   }
  #   |> Pattern.start
  #   |> Pattern.establish

  #   {:ok, stage_1} = Pattern.get_stage(pattern, :make_even)
  #   {:ok, stage_2} = Pattern.get_stage(pattern, :pass_even)

  #   assert [
  #     2, 2, 4, 4, 6, 6, 8, 8, 10, 10
  #   ] == GenStage.stream([{stage_1, max_demand: 1}, {stage_2, max_demand: 1}])
  #        |> Enum.take(10)
  #        |> Enum.map(&(&1.value))
  # end

  # test "and with routing comes neat error handling" do
  #   pattern = %Pattern{
  #     blocks: [
  #       %Block{id: :generator, type: :producer, stream: Stream.cycle([5, 4, 3, 0, 2, 1])},
  #       %Block{id: :at_fault, fun: &(1 / &1)}
  #     ],
  #     subscriptions: [
  #       {:at_fault, :generator}
  #     ]
  #   }
  #   |> Pattern.start
  #   |> Pattern.establish

  #   {:ok, stage} = Pattern.get_stage(pattern, :at_fault)

  #   results = GenStage.stream([{stage, selector: &(&1.route == :ok), max_demand: 1}])
  #   |> Enum.take(5)
  #   |> Enum.map(&(&1.value))

  #   errors = GenStage.stream([{stage, selector: &(&1.route == :error), max_demand: 1}])
  #   |> Enum.take(1)

  #   assert [0.2, 0.25, 1/3, 0.5, 1.0] == results
  #   assert [
  #     %IP{
  #       value: 0,
  #       is_error: true,
  #       error: %{message: "bad argument in arithmetic expression"}
  #     }
  #   ] = errors
  # end
end
