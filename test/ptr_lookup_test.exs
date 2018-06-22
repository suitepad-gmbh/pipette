defmodule PTRLookupTest do
  use ExUnit.Case
  alias Pipette.Client

  setup_all do
    {:ok, _pid} = PTRLookup.start_link()
    :ok
  end

  test "real world example (requires internet connection)" do
    {:ok, client} = Client.start_link(PTRLookup)

    assert {:ok, "crawl-66-249-66-1.googlebot.com."} == Client.call(client, "66.249.66.1")
  end
end
