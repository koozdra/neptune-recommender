defmodule NeptuneRecommender.MixProject do
  use Mix.Project

  def project do
    [
      app: :neptune_recommender,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {NeptuneRecommender.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:poolboy, "~> 1.5"},
      {:httpoison, "~> 1.8"},
      {:jason, "~> 1.0"}
    ]
  end
end
