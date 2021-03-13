defmodule NeptuneRecommender.Reporter do
  use GenServer

  @me Reporter

  def init(init_arg) do
    Process.send_after(self(), :print_report, 0)
    Process.send_after(self(), :print_minute_report, 0)
    {:ok, init_arg}
  end

  def start_link(_) do
    {:ok, start_date_time} = DateTime.now("Etc/UTC")
    GenServer.start_link(__MODULE__, {0, 0, 0, 0, start_date_time}, name: @me)
  end

  def item_processed() do
    GenServer.cast(@me, {:item_processed})
  end

  def recommendation_generated() do
    GenServer.cast(@me, {:recommendation_generated})
  end

  def item_error() do
    GenServer.cast(@me, {:item_error})
  end

  def handle_cast(
        {:item_processed},
        {total_items_processed, total_item_errors, time_span_processed, recs_generated,
         start_date_time}
      ) do
    {:noreply,
     {total_items_processed + 1, total_item_errors, time_span_processed + 1, recs_generated,
      start_date_time}}
  end

  def handle_cast(
        {:recommendation_generated},
        {total_items_processed, total_item_errors, time_span_processed, recs_generated,
         start_date_time}
      ) do
    {:noreply,
     {total_items_processed + 1, total_item_errors, time_span_processed + 1, recs_generated + 1,
      start_date_time}}
  end

  def handle_cast(
        {:item_error},
        {total_items_processed, total_item_errors, time_span_processed, recs_generated,
         start_date_time}
      ) do
    {:noreply,
     {total_items_processed, total_item_errors + 1, time_span_processed, recs_generated,
      start_date_time}}
  end

  def handle_info(
        :print_report,
        {total_items_processed, total_item_errors, time_span_processed, recs_generated,
         start_date_time} = state
      ) do
    {:ok, current_date_time} = DateTime.now("Etc/UTC")
    diff_seconds = DateTime.diff(current_date_time, start_date_time)

    IO.puts(
      "#{total_items_processed} (g:#{recs_generated} e:#{total_item_errors}) #{diff_seconds / 60} minutes"
    )

    Process.send_after(self(), :print_report, 1000)

    {:noreply, state}
  end

  def handle_info(
        :print_minute_report,
        {total_items_processed, total_item_errors, time_span_processed, recs_generated,
         start_date_time} = state
      ) do
    IO.puts("")
    IO.puts(" processing #{time_span_processed} per minute")
    IO.puts("")

    Process.send_after(self(), :print_minute_report, 60000)

    {:noreply, {total_items_processed, total_item_errors, 0, recs_generated, start_date_time}}
  end
end
