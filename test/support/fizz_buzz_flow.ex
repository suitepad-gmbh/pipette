defmodule FizzBuzzFlow do
  use Flow.Module

  flow :to_map
  put :fizz
  put :buzz
  flow :to_string

  def to_map(n), do: %{n: n}

  def fizz(%{n: n}) when rem(n, 3) == 0, do: "fizz"
  def fizz(_), do: nil

  def buzz(%{n: n}) when rem(n, 5) == 0, do: "buzz"
  def buzz(_), do: nil

  def to_string(%{n: n, fizz: fizz, buzz: buzz}) do
    if fizz || buzz do
      "#{fizz}#{buzz}"
    else
      "#{n}"
    end
  end

end

