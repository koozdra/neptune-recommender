defmodule NeptuneRecommender do
  @timeout :infinity

  def recommend do
    ids = 1..10

    ids
    |> Enum.map(fn user_id -> start_worker(user_id) end)
    |> Enum.each(fn task -> on_worker_finish(task) end)
  end

  defp start_worker(user_id) do
    Task.async(fn ->
      :poolboy.transaction(
        :recommender_worker,
        fn pid -> GenServer.call(pid, {:recommend_petition, user_id}) end,
        @timeout
      )
    end)
  end

  defp on_worker_finish(task) do
    task
    |> Task.await(@timeout)
    |> IO.inspect()
  end
end
