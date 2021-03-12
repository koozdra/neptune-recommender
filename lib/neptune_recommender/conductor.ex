defmodule NeptuneRecommender.Conductor do
  use GenServer

  @me Conductor

  def init(num_workers) do
    Process.send_after(self(), :start_processing, 0)
    {:ok, num_workers}
  end

  def start_link(num_workers) do
    GenServer.start_link(__MODULE__, num_workers, name: @me)
  end

  def worker_done() do
    GenServer.cast(@me, :done)
  end

  def handle_info(:start_processing, num_workers) do
    1..num_workers
    |> Enum.each(fn _ ->
      :timer.sleep(1000)
      NeptuneRecommender.WorkerSupervisor.add_worker()
    end)

    {:noreply, num_workers}
  end

  def handle_cast(:done, 1) do
    System.halt(0)
  end

  def handle_cast(:done, num_workers) do
    {:noreply, num_workers - 1}
  end
end
