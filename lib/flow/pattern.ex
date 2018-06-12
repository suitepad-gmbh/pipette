defmodule Flow.Pattern do

  defmacro __using__(_opts \\ []) do
    quote do
      def process_name, do: __MODULE__

      def blocks, do: %{}

      def subscriptions, do: []

      def pattern do
        Flow.Pattern.new(%{
          id: process_name(),
          blocks: blocks(),
          subscriptions: subscriptions()
        })
      end

      def start_link(_opts \\ []), do: Flow.Pattern.Controller.start_link(__MODULE__.pattern())

      def child_spec(_opts \\ []), do: Flow.Pattern.Controller.child_spec(__MODULE__.pattern())

      defoverridable [process_name: 0, blocks: 0, subscriptions: 0]
    end
  end

  alias Flow.Pattern
  alias Flow.Block

  defstruct id: nil,
    blocks: %{},
    subscriptions: []

  def new(%{id: id, blocks: blocks, subscriptions: subscriptions}) do
    blocks = blocks
             |> Map.put(:IN, blocks[:IN] || %Block.PushProducer{})
             |> Map.put(:OUT, blocks[:OUT] || %Block.Consumer{})

    %Pattern{
      id: id,
      blocks: blocks,
      subscriptions: subscriptions
    }
  end

  def start_controller(pattern) do
    {:ok, pid} = Pattern.Controller.start_link(pattern)
    pid
  end

end
