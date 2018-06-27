defmodule Pipette.IP do
  alias Pipette.IP

  @type t :: %IP{value: any(), reply_to: pid(), route: atom(), context: map(), ref: reference()}

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
    update(ip, route: route, value: value)
  end

  def update(%IP{} = ip, opts) when is_list(opts) do
    Map.merge(ip, Map.new(opts))
  end

  def update(%IP{} = ip, value) do
    update(ip, value: value)
  end

  def update(%IP{} = ip, {route, value}, opts) when is_atom(route) and is_list(opts) do
    update(ip, [{:value, value} | [{:route, route} | opts]])
  end

  def update(%IP{} = ip, value, opts) when is_list(opts) do
    update(ip, [{:value, value} | opts])
  end

  def set_context(%IP{} = ip, key, value)
      when is_atom(key) do
    %IP{ip | context: Map.put(ip.context, key, value)}
  end
end
