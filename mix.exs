defmodule Nimble.MixProject do
  use Mix.Project

  def project do
    [
      app: :nimble,
      version: "0.1.0",
      elixir: "~> 1.13.1",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Nimble.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_), do: ["lib", "web"]

  # Specifies your project dependencies.
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.6"},
      {:phoenix_ecto, "~> 4.2.1"},
      {:ecto_sql, "~> 3.6.1"},
      {:postgrex, "~> 0.15.0"},
      {:swoosh, "~> 1.3"},
      {:telemetry_metrics, "~> 0.4.0"},
      {:telemetry_poller, "~> 0.4.0"},
      {:jason, "~> 1.2.1"},
      {:cors_plug, "~> 2.0"},
      {:pbkdf2_elixir, "~> 2.0.0"},
      {:plug_cowboy, "~> 2.3.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
