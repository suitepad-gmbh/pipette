defmodule Pipette.StageTest do
  use ExUnit.Case

  defmodule Test do
    def add(value, number: number) do
      value + number
    end
  end

  alias Pipette.Stage
  alias Pipette.StageTest.Test
  alias Pipette.Recipe
  alias Pipette.Client

  test "handles cast, executes the block and continues the recipe from there" do
    client =
      Recipe.new(%{
        id: __MODULE__,
        stages: %{
          add1: %Stage{handler: {Test, :add, number: 1}},
          add2: %Stage{handler: {Test, :add, number: 2}}
        },
        subscriptions: [
          {:add2, :add1}
        ]
      })
      |> Recipe.start_controller()
      |> Client.start()

    task = Task.async(fn -> Client.pull(client, :add2) end)
    Client.push(client, 0, to: :add1)
    assert Task.await(task) == 3
  end

  # test "hey, we could do routing this these" do
  #   recipe = %Recipe{
  #     stages: [
  #       %Stage.Producer{id: :generator, type: :producer, stream: Stream.iterate(1, &(&1 + 1))},
  #       %Stage{id: :divide_and_conquer, fun: fn
  #         n when rem(n, 2) == 0 -> {:even, n}
  #         n when rem(n, 2) != 0 -> {:odd, n}
  #       end},
  #       %Stage{id: :make_even, fun: &({:even, &1 + 1})},
  #       %Stage{id: :pass_even, fun: &({:even, &1})}
  #     ],
  #     subscriptions: [
  #       {:divide_and_conquer, :generator},
  #       {:make_even, {:divide_and_conquer, :odd}},
  #       {:pass_even, {:divide_and_conquer, :even}}
  #     ]
  #   }
  #   |> Recipe.start
  #   |> Recipe.establish

  #   {:ok, stage_1} = Recipe.get_stage_pid(recipe, :make_even)
  #   {:ok, stage_2} = Recipe.get_stage_pid(recipe, :pass_even)

  #   assert [
  #     2, 2, 4, 4, 6, 6, 8, 8, 10, 10
  #   ] == GenStage.stream([{stage_1, max_demand: 1}, {stage_2, max_demand: 1}])
  #        |> Enum.take(10)
  #        |> Enum.map(&(&1.value))
  # end

  # test "and with routing comes neat error handling" do
  #   recipe = %Recipe{
  #     stages: [
  #       %Stage{id: :generator, type: :producer, stream: Stream.cycle([5, 4, 3, 0, 2, 1])},
  #       %Stage{id: :at_fault, fun: &(1 / &1)}
  #     ],
  #     subscriptions: [
  #       {:at_fault, :generator}
  #     ]
  #   }
  #   |> Recipe.start
  #   |> Recipe.establish

  #   {:ok, stage} = Recipe.get_stage_pid(recipe, :at_fault)

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
