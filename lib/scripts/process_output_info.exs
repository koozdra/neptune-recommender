{:ok, cwd} = File.cwd()
input = File.read!("#{cwd}/lib/data/output_info")

{:ok, output_file_info} = File.open("#{cwd}/lib/scripts/output/output_info_sort_recs", [:append])
{:ok, output_file_info_recruits} = File.open("#{cwd}/lib/scripts/output/output_info_sort_recs_recruits", [:append])
{:ok, output_file_info_signs} = File.open("#{cwd}/lib/scripts/output/output_info_sort_recs_signs", [:append])


input
|> String.split("\n")
|> Enum.map(fn a -> a |> String.split(",") |> Enum.map(&String.trim/1) end)
|> Enum.filter(&(length(&1) > 1))
|> Enum.sort_by(&(&1 |> Enum.at(3) |> String.to_integer()), :desc)
|> Enum.each(fn [user_id, petition_id, type, num_matches | rest] -> 
  IO.binwrite(output_file_info, "#{user_id}, #{petition_id}, #{type}, #{num_matches}, #{Enum.join(rest, "")}\n")
  if type == "R" do
    IO.binwrite(output_file_info_recruits, "#{user_id}, #{petition_id}\n")
  else
    IO.binwrite(output_file_info_signs, "#{user_id}, #{petition_id}\n")
  end
end)
