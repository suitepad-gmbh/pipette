defmodule Pipette.MixProject do
  use Mix.Project

  def project do
    [
      app: :pipette,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      name: "Pipette",
      description: "Pipette is a flow-based programming (FBP) framework for Elixir.",
      source_url: "https://github.com/suitepad-gmbh/pipette",
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # gen_stage are Producer and consumer pipelines with back-pressure control
      {:gen_stage, "~> 0.14"},
      # HTTPoison is used to implement some test examples
      {:httpoison, "~> 1.0", only: :test},
      # jason is used to implement some test examples
      {:jason, "~> 1.0", only: :test},
      # ex_doc is used for generation documentation
      {:ex_doc, "~> 0.18.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Pipette",
      groups_for_modules: [
        "Helpers": [Pipette.GenStage, Pipette.OnDefinition, Pipette.Test],
        "Stages": ~r/Pipette\.Stage/,
      ],
      groups_for_extras: [
        "Examples": ~r/examples/,
        "Guides": ~r/guides/
      ],
      extras: [
        "guides/glossary.md",
        "README.md": [title: "README"],
        "examples/google_bot_verification.md": [title: "Example: Google Bot Verification"],
      ]
    ]
  end

  defp package do
    [
      name: "pipette",
      files: [
        "lib",
        "config",
        "mix.exs",
        "README*",
        "LICENSE*"
      ],
      licenses: ["MIT"],
      maintainers: ["Lukas Rieder", "Mario Olivio Flores", "Paul Spieker", "Hildebrando Rueda"],
      links: %{
        "Github": "https://github.com/suitepad-gmbh/pipette"
      }
    ]
  end
end
