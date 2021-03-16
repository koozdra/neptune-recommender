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
    {:ok, cwd} = File.cwd()
    {:ok, output_file} = File.open("#{cwd}/lib/data/output_recruits", [:append])
    {:ok, output_file_signs} = File.open("#{cwd}/lib/data/output_signs", [:append])
    {:ok, error_file} = File.open("#{cwd}/lib/data/error", [:append])

    GenServer.start_link(
      __MODULE__,
      {output_file, output_file_signs, error_file, 0, 0, 0, 0, start_date_time},
      name: @me
    )
  end

  def item_processed() do
    GenServer.cast(@me, {:item_processed})
  end

  def recommendation_generated(user_id, petition_id) do
    GenServer.cast(@me, {:recommendation_generated, user_id, petition_id})
  end

  def recommendation_generated_sign(user_id, petition_id) do
    GenServer.cast(@me, {:recommendation_generated_sign, user_id, petition_id})
  end

  def item_error(user_id) do
    GenServer.cast(@me, {:item_error, user_id})
  end

  def handle_cast(
        {:item_processed},
        {output_file, output_file_signs, error_file, total_items_processed, total_item_errors,
         time_span_processed, recs_generated, start_date_time}
      ) do
    {:noreply,
     {output_file, output_file_signs, error_file, total_items_processed + 1, total_item_errors,
      time_span_processed + 1, recs_generated, start_date_time}}
  end

  def handle_cast(
        {:recommendation_generated, user_id, petition_id},
        {output_file, output_file_signs, error_file, total_items_processed, total_item_errors,
         time_span_processed, recs_generated, start_date_time}
      ) do
    IO.binwrite(output_file, "#{user_id}, #{petition_id}\n")

    {:noreply,
     {output_file, output_file_signs, error_file, total_items_processed, total_item_errors,
      time_span_processed, recs_generated + 1, start_date_time}}
  end

  def handle_cast(
        {:recommendation_generated_sign, user_id, petition_id},
        {output_file, output_file_signs, error_file, total_items_processed, total_item_errors,
         time_span_processed, recs_generated, start_date_time}
      ) do
    IO.binwrite(output_file_signs, "#{user_id}, #{petition_id}\n")

    {:noreply,
     {output_file, output_file_signs, error_file, total_items_processed, total_item_errors,
      time_span_processed, recs_generated + 1, start_date_time}}
  end

  def handle_cast(
        {:item_error, user_id},
        {output_file, output_file_signs, error_file, total_items_processed, total_item_errors,
         time_span_processed, recs_generated, start_date_time}
      ) do
    IO.binwrite(error_file, "#{user_id}\n")

    {:noreply,
     {output_file, output_file_signs, error_file, total_items_processed, total_item_errors + 1,
      time_span_processed, recs_generated, start_date_time}}
  end

  def handle_info(
        :print_report,
        {output_file, output_file_signs, error_file, total_items_processed, total_item_errors,
         time_span_processed, recs_generated, start_date_time} = state
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
        {output_file, output_file_signs, error_file, total_items_processed, total_item_errors,
         time_span_processed, recs_generated, start_date_time} = state
      ) do
    IO.puts("")
    IO.puts(" processing #{time_span_processed} per minute")
    IO.puts("")

    Process.send_after(self(), :print_minute_report, 60000)

    {:noreply,
     {output_file, output_file_signs, error_file, total_items_processed, total_item_errors, 0,
      recs_generated, start_date_time}}
  end
end
