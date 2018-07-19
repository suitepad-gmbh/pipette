defmodule Pipette.IP do
  @moduledoc """
  The internal message envelope used to pass values from one stage to the next.

  In the flow-based programming (FBP) paradigm, an information packet (IP) is used to encapsulate
  values and context specific information through a network of stages.

  The `Pipette.IP` implements _routing_, _callback_, _context_ and of course _value-transport_ features.

  ## Safety note

  In general there is no need to tamper with the IP-struct itself.

  However there are cases, for example when implementing _custom stages_ or when carrying _context_
  between stages, it is quite handy to have direct access to the IP.

  For these cases we provide functions to safely modify the specific parts of an IP without the risk
  of breaking the internal protocol.

  **It is strongly advised** to not modify/copy the IP-struct directly. Use one of the provided
  functions `Pipette.IP.new/2`, `Pipette.IP.set/3`, `Pipette.IP.set_context/3` or `Pipette.IP.update/2`.
  """

  alias Pipette.IP

  defstruct route: :ok,
            ref: nil,
            value: nil,
            reply_to: nil,
            context: %{}

  @typedoc """
  Describes an instance of an information packet (IP).
  """
  @type t :: %IP{value: any(), reply_to: pid(), route: atom(), context: map(), ref: reference()}

  @spec new(value :: any) :: IP.t
  @spec new({route :: atom, value :: any}) :: IP.t
  @spec new(value :: any, keyword) :: IP.t
  @spec new({route :: atom, value :: any}, keyword) :: IP.t
  @doc """
  Instantiate a new instance of IP with the given value / routed-value.

  Returns `%Pipette.IP{}`

  ## Examples

      iex> IP.new("foo")
      %IP{value: "foo", route: :ok}

      iex> IP.new({:error, :nxdomain})
      %IP{value: :nxdomain, route: :error}
  """
  def new(value, opts \\ [])

  def new({route, value}, opts) when is_atom(route) do
    reply_to = opts[:reply_to]
    %IP{ref: make_ref(), route: route, value: value, reply_to: reply_to}
  end

  def new(value, opts), do: new({:ok, value}, opts)

  @spec update(IP.t, value :: any) :: IP.t
  @spec update(IP.t, {route :: atom, value :: any}) :: IP.t
  @doc """
  Update the value/route of an IP.

  Routing works by providing a 2-tuple `{atom(), value}` as value.
  Any other value is assumed to route as `{:ok, value}`.

  Routing is a very powerful concept in `Pipette`, you can use it to build very expressive
  FBP applications with simple functional building blocks.

  Returns `%Pipette.IP{}`

  ## Examples

      iex> ip = IP.new("foo")
      iex> IP.update(ip, "bar")
      %IP{route: :ok, value: "bar"}
      iex> IP.update(ip, {:error, :nofile})
      %IP{route: :error, value: :nofile}
      iex> IP.update(ip, {:success, %{state: "value", count: 123}})
      %IP{route: :success, value: %{state: "value", count: 123}}
  """
  def update(%IP{} = ip, {route, value}) when is_atom(route) do
    %IP{ip | route: route, value: value}
  end

  def update(%IP{} = ip, value) do
    update(ip, {:ok, value})
  end

  @spec set(IP.t, :value, any) :: IP.t
  @spec set(IP.t, :reply_to, pid | nil) :: IP.t
  @spec set(IP.t, :ref, reference | nil) :: IP.t
  @spec set(IP.t, :route, atom) :: IP.t
  @doc """
  Overwrite one of the given fields of an IP.

  Providing `nil` to `:reply_to` or `ref` field will unset the value.
  All calls are strictly type checked. Setting `:value` will delegate to `Pipette.IP.update/2`.

  Returns `%Pipette.IP{}`

  ## Note

  Only use if you know what you are doing.
  Tampering with `:reply_to` or `:ref` will affect `Pipette.Client` functionality.

  ## Examples

      iex> ip = IP.new("foo")
      %IP{value: "foo", route: :ok}
      iex> IP.set(ip, :reply_to, self())
      %IP{value: "foo", route: :ok, reply_to: self()}
      iex> IP.set(ip, :route, :fatal)
      %IP{value: "foo", route: :fatal, reply_to: self()}
  """
  def set(%IP{} = ip, :value, value), do: update(ip, value)

  def set(%IP{} = ip, :route, route) when is_atom(route), do: Map.put(ip, :route, route)

  def set(%IP{} = ip, :ref, ref) when is_reference(ref), do: Map.put(ip, :ref, ref)

  def set(%IP{} = ip, :ref, nil), do: Map.put(ip, :ref, nil)

  def set(%IP{} = ip, :reply_to, pid) when is_pid(pid), do: Map.put(ip, :reply_to, pid)

  def set(%IP{} = ip, :reply_to, nil), do: Map.put(ip, :reply_to, nil)

  @spec set_context(IP.t, atom, any) :: IP.t
  @doc """
  Set a key/value pair on the context field, preserving other keys on context.

  This feature is particularly useful if you need to preserves values across many stages.

  For example, you might have a specific message_id that needs to be updated on an external system,
  after processing has finished. But the message_id is only available at the producing stage.

  Using the _context_ you can preserve such values while the message is traveling through the network.

  Returns `%Pipette.IP{}`

  ## Note

  **Do not use _context_** when you actually want to provide data to stages. This is considered
  a misuse of context. You should take care to separate data (i.e. values) from metadata (i.e. context).

  ## Examples

      iex> ip = IP.new("foo")
      iex> ip = IP.set_context(ip, :message_id, 123)
      %IP{value: "foo", context: %{message_id: 123}}
      iex> ip = IP.set_context(ip, :kafka, %{topic: "inbox"})
      %IP{value: "foo", context: %{message_id: 123, topic: "inbox"}}
      iex> ip = IP.set_context(ip, :message_id, 456)
      %IP{value: "foo", context: %{message_id: 456, topic: "inbox"}}
  """
  def set_context(%IP{} = ip, key, value)
      when is_atom(key) do
    %IP{ip | context: Map.put(ip.context, key, value)}
  end
end
