defmodule Flow.Pattern do

  defmacro __using__(opts \\ []) do
    quote do
      def blocks, do: %{}

      def subscriptions, do: []

      def pattern do
        Flow.Pattern.new(%{id: __MODULE__, blocks: blocks(), subscriptions: subscriptions()})
      end

      def start_link(), do: Flow.Pattern.Controller.start_link(__MODULE__.pattern())

      def child_spec(), do: Flow.Pattern.Controller.child_spec(__MODULE__.pattern())

      defoverridable [blocks: 0, subscriptions: 0]
    end
  end

  alias Flow.Pattern
  alias Flow.Block

  defstruct id: nil,
    blocks: %{},
    subscriptions: []

  def new(%{id: id, blocks: blocks, subscriptions: subscriptions} = args) do
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

