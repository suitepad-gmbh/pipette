defmodule Pipette.MixProject do
  use Mix.Project

  def project do
    [
      app: :pipette,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Producer and consumer pipelines with back-pressure for Elixir
      {:gen_stage, "~> 0.13"},
      # We use HTTPoison to implement some test examples
      {:httpoison, "~> 1.0", only: :test},
      # We use jason to implement some test examples
      {:jason, "~> 1.0", only: :test}
    ]
  end
end
