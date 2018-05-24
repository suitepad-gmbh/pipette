defmodule ModuleFlows do
  use Flow.Macro

  flow :zero
  flow AddTen
  flow AddTwoFlow

  def zero(state, _) do
    %{state | n: 0}
  end

  defmodule AddTen do
    def call(%{n: n}, _) do
      %{n: n + 10}
    end
  end

  defmodule AddTwoFlow do
    use Flow.Macro

    flow :plus_one
    flow :plus_one

    def plus(%{n: n} = state, _) do
      %{state | n: n + 1}
    end
  end
end

