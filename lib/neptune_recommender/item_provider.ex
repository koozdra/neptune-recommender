defmodule NeptuneRecommender.ItemProvider do
  use GenServer

  @me __MODULE__

  def start_link(_) do
    {:ok, cwd} = File.cwd()
    file_stream = File.stream!("#{cwd}/lib/data/input_real")
    GenServer.start_link(__MODULE__, {file_stream, :listing}, name: @me)
  end

  def next_item do
    GenServer.call(@me, {:next_item}, 3 * 600_000)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  # https://elixirforum.com/t/genstage-unexpected-ssl-closed-message/9688/14
  def handle_info({:ssl_closed, _msg}, state), do: {:noreply, state}

  def handle_call({:next_item}, _from, {_, :complete}) do
    {:reply, nil, {[], :complete}}

    # uncomment for infinite loop
    # [head | tail] = get_s3_page()
    # {:reply, head, {tail, :listing}}
  end

  def handle_call({:next_item}, _from, {file_stream, :listing}) do
    items = Enum.take(file_stream, 1)

    case items do
      [] ->
        {:reply, nil, {[], :complete}}

      [item | _rest] ->
        file_stream = Enum.drop(file_stream, 1)

        formatted_item =
          item
          |> String.trim()
          |> String.replace(",", "")

        {:reply, formatted_item, {file_stream, :listing}}
    end
  end
end
