defmodule NeptuneRecommender.RecommenderWorker do
  use GenServer

  alias NeptuneRecommender.GremlinConsole

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_call({:recommend_petition, user_id}, _from, state) do
    IO.puts("recommending #{user_id}")

    r = GremlinConsole.recruits_petitions(user_id)

    {:reply, r, state}
  end
end
