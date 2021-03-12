defmodule NeptuneRecommender.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      NeptuneRecommender.ItemProvider,
      NeptuneRecommender.WorkerSupervisor,
      {NeptuneRecommender.Conductor, 1000}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NeptuneRecommender.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp poolboy_config do
    [
      name: {:local, :recommender_worker},
      worker_module: NeptuneRecommender.RecommenderWorker,
      size: 5,
      max_overflow: 0
    ]
  end
end
