defmodule NeptuneRecommender do
  @timeout 500_000

  def recommend do
    {:ok, cwd} = File.cwd()
    file_stream = File.stream!("#{cwd}/lib/data/input_small")

    IO.inspect(file_stream)

    # file_stream
    # |> Enum.map(&String.trim/1)
    # |> Enum.map(fn user_id -> start_worker(user_id) end)
    # |> Enum.each(fn task -> on_worker_finish(task) end)

    a = Enum.take(file_stream, 30) |> IO.inspect(label: "a")

    file_stream = Enum.drop(file_stream, 30)
    # IO.inspect(a, label: "a")
    b = Enum.take(file_stream, 30) |> IO.inspect(label: "b")
    # IO.inspect(b, label: "b")

    1..10

    "result"
  end

  defp start_worker(user_id) do
    Task.async(fn ->
      :poolboy.transaction(
        :recommender_worker,
        fn pid -> GenServer.call(pid, {:recommend_petition, user_id}, :infinity) end,
        @timeout
      )
    end)
  end

  defp on_worker_finish(task) do
    {:ok, cwd} = File.cwd()
    {:ok, file} = File.open("#{cwd}/lib/data/output", [:append])

    task
    |> Task.await(@timeout)
    |> (fn {user_id, recommendations} ->
          IO.puts("finished: #{user_id}")

          recommendations
          |> Enum.take(1)
          |> Enum.each(fn {num_matches, petition_id, title} ->
            # IO.puts("#{user_id}, #{petition_id}, #{title}")
            IO.binwrite(file, "#{user_id}, #{petition_id}\n")
          end)
        end).()
  end
end
