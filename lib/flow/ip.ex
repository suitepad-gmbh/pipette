defmodule Flow.IP do
  alias Flow.IP

  defstruct route: :ok,
            ref: nil,
            value: nil,
            reply_to: nil,
            context: %{}

  def new(value, opts \\ [])

  def new({route, value}, opts) when is_atom(route) do
    reply_to = opts[:reply_to]
    %IP{ref: make_ref(), route: route, value: value, reply_to: reply_to}
  end

  def new(value, opts), do: new({:ok, value}, opts)

  def update(%IP{} = ip, {route, value}) when is_atom(route) do
    %IP{ip | route: route, value: value}
  end

  def update(%IP{} = ip, value), do: update(ip, {:ok, value})

  def set_context(%IP{} = ip, key, value)
      when is_atom(key) do
    %IP{ip | context: Map.put(ip.context, key, value)}
  end
end
