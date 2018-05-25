defmodule Flow do

  defstruct name: nil,
    stages: [],
    supervisor_pid: nil,
    producer_name: nil,
    consumer_name: nil

  def call(%Flow{producer_name: producer_name, consumer_name: consumer_name}, value) do
    pid = self()
    monitor = Process.monitor(consumer_name)
    ip = %Flow.IP{reply_to: pid, value: value}

    GenStage.cast(producer_name, ip)
    await_response(pid, monitor)
  end

  def cast(%Flow{producer_name: producer_name}, value) do
    ip = %Flow.IP{value: value}
    GenStage.cast(producer_name, ip)
  end

  defp await_response(pid, monitor) do
    receive do
      %Flow.IP{reply_to: ^pid} = ip ->
        Process.demonitor(monitor)
        ip.value

      {:DOWN, ^monitor, _, _, _reason} ->
        raise "Consumer went down"

      _ ->
        await_response(pid, monitor)
    end
  end

end

