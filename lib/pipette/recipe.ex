defmodule Pipette.Recipe do
  defmacro __using__(_opts \\ []) do
    quote do
      Module.register_attribute(__MODULE__, :stage, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :subscribe, accumulate: true, persist: true)

      def process_name, do: __MODULE__

      def stages do
        __MODULE__.__info__(:attributes)
        |> Keyword.get_values(:stage)
        |> List.flatten()
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
    end
  end

  alias Pipette.Recipe
  alias Pipette.Stage

  defstruct id: nil,
            stages: %{},
            subscriptions: []

  def new(%{id: id, stages: stages, subscriptions: subscriptions}) do
    stages =
      stages
      |> Map.put(:IN, stages[:IN] || %Stage.PushProducer{})
      |> Map.put(:OUT, stages[:OUT] || %Stage.Consumer{})

    %Recipe{
      id: id,
      stages: stages,
      subscriptions: subscriptions
    }
  end

  def start_controller(recipe) do
    {:ok, pid} = Pipette.Controller.start_link(recipe)
    pid
  end
end
