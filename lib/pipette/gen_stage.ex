defmodule Pipette.GenStage do
  @moduledoc """
  Base module to use when building a custom stage.
  """

  defmacro __using__(opts \\ []) do
    stage_type = Keyword.get(opts, :stage_type, :producer_consumer)

    quote bind_quoted: [stage_type: stage_type] do
      use GenStage
      @stage_type stage_type

      @doc false
      def stage_type, do: @stage_type

      @doc false
      def child_spec(stage, opts \\ []) do
        %{id: __MODULE__, start: {__MODULE__, :start_link, [stage, opts]}}
      end

      @doc false
      def start_link(stage, opts \\ []) do
        GenStage.start_link(__MODULE__, stage, opts)
      end

      @doc false
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
