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

  defp process_item(nil) do
    NeptuneRecommender.Conductor.worker_done()
    {:noreply, nil}
  end

  defp process_item(user_id) do
    IO.puts("Starting: #{user_id}")

    case GremlinConsole.recruits_petitions(user_id, 1, 5) do
      {:ok, result} ->
        # IO.inspect(result)

        # IO.puts("finished: #{user_id}")
        IO.puts("finished: #{user_id}")

        # {:ok, cwd} = File.cwd()
        # {:ok, file} = File.open("#{cwd}/lib/data/output", [:append])

        result
        |> Enum.take(1)
        |> Enum.each(fn {num_matches, petition_id, title} ->
          IO.puts("#{user_id}, #{petition_id}, #{title}")
          # IO.binwrite(file, "#{user_id}, #{petition_id}\n")
        end)

      {:error} ->
        IO.puts("ERRRROORRRRRRRR")
    end

    Process.send_after(self(), :process_item, 0)

    {:noreply, nil}
  end

  # def handle_call({:recommend_petition, user_id}, _from, state) do
  #   IO.puts("recommending #{user_id}")

  #   result = GremlinConsole.recruits_petitions(user_id, 1, 5)

  #   {:reply, {user_id, result}, state}
  # end
end
