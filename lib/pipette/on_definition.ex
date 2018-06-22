defmodule Pipette.OnDefinition do

  defmacro __using__(_opts) do
    quote do
      use Pipette.Recipe

      @on_definition Pipette.OnDefinition
    end
  end

  def __on_definition__(_env, _kind, name, _args, _guards, _body)
  when name in [:subscriptions, :stages, :recipe], do: nil

  def __on_definition__(env, :def, name, _args, _guards, _body) do
    mod = env.module
    stages = Module.get_attribute(mod, :stage)

    unless Keyword.has_key?(stages, name) do
      stage = %Pipette.Stage{handler: {mod, name, []}}
      Module.put_attribute(mod, :stage, {name, stage})
    end
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: nil

end
