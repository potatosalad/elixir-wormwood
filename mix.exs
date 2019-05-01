defmodule Wormwood.MixProject do
  use Mix.Project

  def project() do
    [
      app: :wormwood,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application() do
    [
      extra_applications: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps() do
    [
      {:nimble_parsec, "~> 0.5.0"},
      {:ojson, "~> 1.0"}
    ]
  end
end
