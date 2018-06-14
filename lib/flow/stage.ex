defmodule Flow.Stage do
  defmacro __using__(opts \\ []) do
    stage_type = Keyword.fetch!(opts, :stage_type)

    quote bind_quoted: [stage_type: stage_type] do
      use GenStage
      @stage_type stage_type

      def stage_type, do: @stage_type

      def child_spec(block, opts \\ []) do
        %{id: __MODULE__, start: {__MODULE__, :start_link, [block, opts]}}
      end

      def start_link(block, opts \\ []) do
        GenStage.start_link(__MODULE__, block, opts)
      end

      def init(block) do
        case @stage_type do
          :consumer ->
            {:consumer, block}

          stage_type when stage_type in [:producer, :producer_consumer] ->
            dispatcher = {GenStage.BroadcastDispatcher, []}
            {stage_type, block, dispatcher: dispatcher}
        end
      end

      defoverridable child_spec: 2, start_link: 2, init: 1
    end
  end
end
