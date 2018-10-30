defmodule Pipette.Recipe do
  @moduledoc """
  Represents a graph of labelled and connected stages.

  ## Note

  The `:IN` and `:OUT` stages carry a special meaning, that is required for interoperability of the
  `Pipette.Client` protocol.

  It is generally advised to write recipes that have a defined `:IN` and `:OUT` stage. This encourages
  re-usability of recipes within other recipes, and is the basis for the `Pipette.Client` protocol.

  By default, `:IN` is provided as a `Pipette.Stage.PushProducer` and `:OUT` is provided as a `Pipette.Stage.Consumer`.

  `:IN` and `:OUT` must be explicitly subscribed. They can be ignored unless needed.

  ## Example

      defmodule AddOne
        use Pipette.Recipe

        @stage IN: %Stage{handler: fn value -> value + 1 end}
        @subscribe OUT: :IN
      end

  Now you can start the recipe and interact with it, using a `Pipette.Client` for example.

      iex> AddOne.recipe()
      %Pipette.Recipe{
        stages: %{IN: %Stage{}, OUT: %Stage.Consumer{}},
        subscriptions: [
          {:IN, :OUT}
        ]
      }
      iex> {:ok, pid} = AddOne.start_link()
      iex> client = Pipette.Client.start(pid)
      iex> Pipette.Client.call(client, 2)
      {:ok, 3}

  """

  defmacro __using__(_opts \\ []) do
    quote do
      Module.register_attribute(__MODULE__, :stage, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :subscribe, accumulate: true, persist: true)

      def process_name, do: __MODULE__

      def stages do
        __MODULE__.__info__(:attributes)
        |> Keyword.get_values(:stage)
        |> List.flatten()
        |> complete_stage_definition()
        |> Enum.into(%{})
      end

      def subscriptions do
        __MODULE__.__info__(:attributes)
        |> Keyword.get_values(:subscribe)
        |> List.flatten()
      end

      def recipe do
        Pipette.Recipe.new(%{
          id: process_name(),
          stages: stages(),
          subscriptions: subscriptions()
        })
      end

      def start_link(_opts \\ []), do: Pipette.Controller.start_link(__MODULE__.recipe())

      def child_spec(_opts \\ []), do: Pipette.Controller.child_spec(__MODULE__.recipe())

      defoverridable process_name: 0, recipe: 0, stages: 0, subscriptions: 0

      defp complete_stage_definition(stages) do
        default_stage = Application.get_env(:pipette, :default_stage, Pipette.Stage)

        Enum.map(stages, fn
          {key, %{__struct__: _} = value} -> {key, value}
          {key, handler} -> {key, struct(default_stage, %{handler: handler})}
        end)
      end
    end
  end

  alias Pipette.Recipe
  alias Pipette.Stage

  defstruct id: nil,
            stages: %{},
            subscriptions: []

  @typedoc """
  An instance of a recipe.
  """
  @type t :: %Pipette.Recipe{stages: stages_t, subscriptions: subscriptions_t}

  @type stages_t :: %{atom => struct}

  @type subscriptions_t :: [
          {from :: atom, to :: atom} | {from :: atom, to :: atom, route :: atom}
        ]

  @spec new(%{stages: stages_t, subscriptions: subscriptions_t}) :: Pipette.Recipe.t()
  @doc """
  Returns a Pipette recipe struct, and provides defaults for `:IN` and `:OUT`.
  """
  def new(%{stages: stages, subscriptions: subscriptions} = recipe) do
    stages =
      stages
      |> Map.put(:IN, stages[:IN] || %Stage.PushProducer{})
      |> Map.put(:OUT, stages[:OUT] || %Stage.Consumer{})

    %Recipe{
      id: Map.get(recipe, :id),
      stages: stages,
      subscriptions: subscriptions
    }
  end

  @spec start_controller(%{stages: stages_t, subscriptions: subscriptions_t} | Pipette.Recipe.t()) ::
          pid
  @doc """
  Start a recipe controller.

  Returns the pid of the `Pipette.Controller`.
  """
  def start_controller(recipe) do
    {:ok, pid} = Pipette.Controller.start_link(recipe)
    pid
  end
end
