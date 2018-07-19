defmodule Pipette.OnDefinition do
  @moduledoc """
  Convenience module to quickly build a recipe out of a module and its functions.

  `Pipette.OnDefinition`, as its name states, works by providing stages at compile
  time using the `@on_definition` macro, for all public functions defined in the module,
  labelled by the function name.

  It provides the module with `use Pipette.Recipe` so you can still use the `@stage` and `@subscribe`
  module attribute to further refine the recipe.

  ## Example

      defmodule FizzBuzz do
        use Pipette.OnDefinition

        @subscribe fizz: :IN
        @subscribe buzz: :fizz
        @subscribe number: :buzz
        @subscribe OUT: :number

        def fizz(n) when rem(n, 3) == 0, do: {n, "fizz"}
        def fizz(n), do: {n, ""}
        def buzz({n, s}) when rem(n, 5) == 0, do: {n, s <> "buzz"}
        def buzz({n, s}), do: {n, s}
        def number({n, ""}), do: n
        def number({_n, s}), do: s
      end

      iex> {:ok, pid} = FizzBuzz.start_link
      iex> client = Pipette.Client.start(pid)
      iex> for n <- 1..15, into: [], do: Pipette.Client.call!(client, n)
      [1, 2, "fizz", 4, "buzz", "fizz", 7, 8, "fizz", "buzz", 11, "fizz", 13, 14, "fizzbuzz"]
  """

  defmacro __using__(_opts) do
    quote do
      use Pipette.Recipe

      @on_definition Pipette.OnDefinition
    end
  end

  def __on_definition__(_env, _kind, name, _args, _guards, _body)
  when name in [:subscriptions, :stages, :recipe], do: nil

  def __on_definition__(env, :def, name, _args, _guards, _body) do
    mod = env.module
    stages = Module.get_attribute(mod, :stage)

    unless Keyword.has_key?(stages, name) do
      stage = %Pipette.Stage{handler: {mod, name, []}}
      Module.put_attribute(mod, :stage, {name, stage})
    end
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: nil

end
