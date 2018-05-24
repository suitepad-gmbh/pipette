defmodule Flow.Module do

  alias Flow.Stage

  defmacro flow(atom) do
    quote do
      @stages %Stage{module: __MODULE__, function: unquote(atom)}
    end
  end

  defmacro put(atom) do
    quote do
      @stages %Stage{module: __MODULE__, function: unquote(atom), op: {:put, unquote(atom)}}
    end
  end

  defmacro __using__(_args) do
    quote do
      import Flow.Module
      @before_compile Flow.Module

      Module.register_attribute __MODULE__, :stages, accumulate: true
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def flow do
        %Flow{stages: Enum.reverse(@stages)}
      end
    end
  end

end
