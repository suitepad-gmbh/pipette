defmodule Pipette.Recipe do
  defmacro __using__(_opts \\ []) do
    quote do
      def process_name, do: __MODULE__

      def stages, do: %{}

      def subscriptions, do: []

      def recipe do
        Pipette.Recipe.new(%{
          id: process_name(),
          stages: stages(),
          subscriptions: subscriptions()
        })
      end

      def start_link(_opts \\ []), do: Pipette.Controller.start_link(__MODULE__.recipe())

      def child_spec(_opts \\ []), do: Pipette.Controller.child_spec(__MODULE__.recipe())

      defoverridable process_name: 0, stages: 0, subscriptions: 0
    end
  end

  alias Pipette.Recipe
  alias Pipette.Stage

  defstruct id: nil,
            stages: %{},
            subscriptions: []

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

  def start_controller(recipe) do
    {:ok, pid} = Pipette.Controller.start_link(recipe)
    pid
  end
end
