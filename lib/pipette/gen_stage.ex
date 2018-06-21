defmodule Pipette.GenStage do
  defmacro __using__(opts \\ []) do
    stage_type = Keyword.get(opts, :stage_type, :producer_consumer)

    quote bind_quoted: [stage_type: stage_type] do
      use GenStage
      @stage_type stage_type

      def stage_type, do: @stage_type

      def child_spec(stage, opts \\ []) do
        %{id: __MODULE__, start: {__MODULE__, :start_link, [stage, opts]}}
      end

      def start_link(stage, opts \\ []) do
        GenStage.start_link(__MODULE__, stage, opts)
      end

      def init(stage) do
        case @stage_type do
          :consumer ->
            {:consumer, stage}

          stage_type when stage_type in [:producer, :producer_consumer] ->
            dispatcher = {GenStage.BroadcastDispatcher, []}
            {stage_type, stage, dispatcher: dispatcher}
        end
      end

      defoverridable child_spec: 2, start_link: 2, init: 1
    end
  end
end
