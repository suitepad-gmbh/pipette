defmodule Flow.IP do
  alias Flow.IP

  defstruct route: :ok,
    value: nil,
    reply_to: nil,
    is_error: false,
    error: nil

  def new(value, opts \\ [])

  def new({route, value}, opts) when is_atom(route) do
    reply_to = opts[:reply_to]
    %IP{route: route, value: value, reply_to: reply_to}
  end

  def new(value, opts), do: new({:ok, value}, opts)

  def update(ip, {route, value}) when is_atom(route) do
    %IP{ip | route: route, value: value}
  end

  def update(ip, value), do: update(ip, {:ok, value})
end

