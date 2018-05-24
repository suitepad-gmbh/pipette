defmodule Flow.Composer do

  alias Flow.Stage

  def producer_name(%Flow{name: name}) do
    :"Flow.Stages.Producer_#{name}__#{System.unique_integer()}"
  end

  def consumer_name(%Flow{name: name}) do
    :"Flow.Stages.Consumer_#{name}__#{System.unique_integer()}"
  end

  def worker_name(%Stage{fun: fun}) when is_function(fun) do
    :"Flow.Stages.Worker___#{System.unique_integer()}"
  end

  def worker_name(%Stage{module: module, function: function}) do
    :"Flow.Stages.Worker_#{module}.#{function}__#{System.unique_integer()}"
  end

  def start(flow) do
    {flow, specs} = build(flow)

    {:ok, supervisor_pid} = Supervisor.start_link(specs, strategy: :rest_for_one)

    %Flow{flow | supervisor_pid: supervisor_pid}
  end

  def build(flow) do
    producer_name = producer_name(flow)
    producer_spec = %{
      id: producer_name,
      start: {Flow.Stages.Producer, :start_link, [nil, [name: producer_name]]}
    }
    flow = %Flow{flow | producer_name: producer_name}

    {outlets, worker_specs} = build_stages(flow)

    consumer_name = consumer_name(flow)
    consumer_spec = %{
      id: consumer_name,
      restart: :permanent,
      start: {Flow.Stages.Consumer, :start_link, [outlets, [name: consumer_name]]}
    }
    flow = %Flow{flow | consumer_name: consumer_name}

    specs = [producer_spec] ++ worker_specs ++ [consumer_spec]
    {flow, specs}
  end

  def build_stages(%Flow{producer_name: producer_name, stages: stages} = flow) do
    Enum.reduce(stages, {[producer_name], []}, fn
      stage, {producer_names, acc} ->
        parallel = 1 # TODO: no parallism for now
        stage = %{stage | producers: producer_names}
        {outlets, new_specs} = (1..parallel)
                                     |> Enum.map(fn(_) -> build_stage(stage) end)
                                     |> Enum.unzip
        {outlets, acc ++ new_specs}
    end)
  end

  def build_stage(stage) do
    worker_name = worker_name(stage)
    # worker_spec = worker(Flow.Stages.Worker, [stage, [name: worker_name]], id: worker_name)
    worker_spec = %{
      id: worker_name,
      start: {Flow.Stages.Worker, :start_link, [stage, [name: worker_name]]}
    }
    {worker_name, worker_spec}
  end

end

