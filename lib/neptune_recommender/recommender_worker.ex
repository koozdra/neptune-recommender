defmodule NeptuneRecommender.RecommenderWorker do
  use GenServer

  alias NeptuneRecommender.GremlinConsole

  def start_link(_) do
    GenServer.start_link(__MODULE__, :no_args)
  end

  def init(:no_args) do
    Process.send_after(self(), :process_item, 0)
    {:ok, nil}
  end

  def handle_info(:process_item, _) do
    NeptuneRecommender.ItemProvider.next_item() |> process_item()
  end

  # https://elixirforum.com/t/genstage-unexpected-ssl-closed-message/9688/14
  def handle_info({:ssl_closed, _msg}, state), do: {:noreply, state}

  defp process_item(nil) do
    NeptuneRecommender.Conductor.worker_done()
    {:noreply, nil}
  end

  defp process_item(user_id) do
    case GremlinConsole.recruits_petitions(user_id, 1) do
      {:ok, []} ->
        fallback_query(user_id)

      {:ok, [{num_matches, petition_id, title} | _rest]} ->
        NeptuneRecommender.Reporter.recommendation_generated(user_id, petition_id, title, num_matches)

      {:error} ->
        fallback_query(user_id)
    end

    NeptuneRecommender.Reporter.item_processed()

    Process.send_after(self(), :process_item, 0)

    {:noreply, nil}
  end

  defp fallback_query(user_id) do
    case GremlinConsole.connect_by_signatures(user_id, 1, 20) do
      {:ok, [{num_matches, petition_id, title} | _rest]} ->
        # IO.puts("#{num_matches}, #{petition_id}, #{title}")
        NeptuneRecommender.Reporter.recommendation_generated_sign(user_id, petition_id, title, num_matches)
      {:ok, []} ->
        NeptuneRecommender.Reporter.no_recommendation(user_id)
      {:error} ->
        NeptuneRecommender.Reporter.item_error(user_id)
    end
  end
end
