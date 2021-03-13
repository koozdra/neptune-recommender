# mix run --no-start lib/gremlin_console.ex

defmodule NeptuneRecommender.GremlinConsole do
  def get_status do
    {:ok, %{body: body}} =
      HTTPoison.get(
        "https://dimitri-test-cluster.cluster-cbumrcbxuzww.us-west-2.neptune.amazonaws.com:8182/status"
      )

    Jason.decode!(body)
  end

  def send_query(query) do
    clean_query =
      query
      |> String.split("\n")
      |> Enum.map(fn line -> String.trim(line) end)
      |> Enum.join("")

    # IO.inspect("running query")
    # IO.inspect(clean_query)

    # dimitri-test-cluster.cluster-ro-cbumrcbxuzww.us-west-2.neptune.amazonaws.com

    response =
      HTTPoison.post(
        "https://dimitri-test-cluster.cluster-ro-cbumrcbxuzww.us-west-2.neptune.amazonaws.com:8182/gremlin",
        "{\"gremlin\":\"#{clean_query}\"}",
        [],
        timeout: :infinity,
        recv_timeout: :infinity
      )

    case response do
      {:ok, %{body: body}} ->
        case Jason.decode!(body) do
          %{"result" => %{"data" => data}} ->
            {:ok, data}

          result ->
            IO.inspect(result)
            {:error}
        end

      _ ->
        {:error}
    end
  end

  def get_petition_title(petition_id) do
    query = """
    g.V('petition_#{petition_id}').values('title')
    """

    send_query(query)
    |> get_in(["@value"])
    |> List.first()
  end

  def get_petition_signatures(petition_id) do
    query = """
    g.V('petition_#{petition_id}').in('signed').count()
    """

    send_query(query)
    |> get_in(["@value"])
    |> List.first()
    |> get_in(["@value"])
  end

  def petition_cosigner_petitions(petition_id) do
    query = """
    g.V('petition_#{petition_id}').as('source_petition')
    .in('signed')
    .out('signed').where(neq('source_petition'))
    .values('id')
    .timeLimit(1000)
    .groupCount()
    .order(local)
      .by(values, desc)
    .limit(local, 20)
    """

    # match version of the above, consider replacing
    #     g.V()
    # .match( 
    #   __.as('subject').hasId('petition_#{petition_id}'),
    #   __.as('subject').in('signed').as('subject_signers').timeLimit(1000),
    #   __.as('subject_signers').out('signed').where(neq('subject')).as('subject_signers_petitions').timeLimit(1000)
    # )

    process_group_count_result(send_query(query))
  end

  def recruits_petitions(user_id, result_limit, time_limit) do
    # query = """
    # g.V()
    # .match( 
    #   __.as('user').hasId('user_#{user_id}'),
    #   __.as('user').out('recruited').out('signed').as('recruitee_signed_petitions'),
    #   __.not(__.as('recruitee_signed_petitions').in('signed').hasId('user_#{user_id}'))
    # )
    # .timeLimit(#{time_limit})
    # .select('recruitee_signed_petitions')
    # .groupCount()
    # .order(local)
    #   .by(values, desc)
    # .limit(local, #{result_limit})
    # """

    # query = """
    # g.V()
    # .match( 
    #   __.as('user').hasId('user_#{user_id}'),
    #   __.as('user').out('recruited').out('signed').as('recruitee_signed_petitions'),
    #   __.not(__.as('recruitee_signed_petitions').in('signed').hasId('user_#{user_id}')),
    #   __.as('user').in('recruited').out('signed').as('recruiters_signed_petitions'),
    #   __.not(__.as('recruiters_signed_petitions').in('signed').hasId('user_#{user_id}'))
    # )
    # .timeLimit(#{time_limit})
    # .select('recruitee_signed_petitions', 'recruiters_signed_petitions')
    # .groupCount()
    # .order(local)
    #   .by(values, desc)
    # .limit(local, #{result_limit})
    # """

    # .values('title')

    query = """
    g
    .V('user_#{user_id}')
    .union(
      __.out('recruited').out('signed'),
      __.in('recruited').out('signed'),
      __.in('recruited').out('recruited').out('signed')
    )
    .where(__.not(__.in('signed').hasId('user_#{user_id}')))
    .groupCount()
    .order(local)
      .by(values, desc)
    .limit(local, #{result_limit})
    """

    case send_query(query) do
      {:ok, result} ->
        {:ok,
         result
         |> get_in(["@value"])
         |> List.first()
         |> get_in(["@value"])
         |> Enum.chunk_every(2)
         |> Enum.map(fn [
                          %{
                            "@value" => %{
                              "id" => "petition_" <> petition_id,
                              "properties" => %{"title" => title_props}
                            }
                          },
                          %{"@value" => count}
                        ] ->
           title =
             title_props
             |> List.first()
             |> get_in(["@value"])
             |> get_in(["value"])

           {count, petition_id, title}
         end)}

      _ ->
        {:error}
    end
  end

  def cosigner_petitions(user_id) do
    query = """
    g.V()
    .match( 
      __.as('subject').hasId('user_#{user_id}'),
      __.as('subject').out('signed').as('subject_signed_petitions').timeLimit(1000),
      __.as('subject_signed_petitions').in('signed').as('cosigners').timeLimit(1000),
      __.as('cosigners').out('signed').as('cosigner_petitions').where(neq('subject_signed_petitions')).timeLimit(1000)
    )
    .timeLimit(1000)
    .select('cosigner_petitions')
    .values('title')
    .groupCount()
    .order(local)
      .by(values, desc)
    .limit(local, 20)
    """

    process_group_count_result(send_query(query))
  end

  def copetition_signers(petition_id) do
    query = """
    g.V()
    .match( 
      __.as('subject').hasId('petition_#{petition_id}'),
      __.as('subject').in('signed').as('subject_signers').timeLimit(1000),
      __.as('subject_signers').out('signed').where(neq('subject')).as('subject_signers_petitions').timeLimit(1000),
      __.as('subject_signers_petitions').in('signed').as('subject_signers_petitions_signers')
    )
    .timeLimit(1000)
    .select('subject_signers_petitions_signers')
    .id()
    .dedupe()
    """

    send_query(query)
    |> get_in(["@value"])
  end

  # __.as('subject_signers_petitions').in('signed').as('subject_signers_petitions_signers')
  def copetition_signers_linking_petitions(petition_id) do
    query = """
    g.V()
    .match( 
      __.as('subject').hasId('petition_#{petition_id}'),
      __.as('subject').in('signed').as('subject_signers').timeLimit(1000),
      __.as('subject_signers').out('signed').where(neq('subject')).as('subject_signers_petitions').timeLimit(1000)
      
    )
    .timeLimit(1000)
    .select('subject_signers_petitions')
    .values('title')
    .groupCount()
    .order(local)
      .by(values, desc)
    .limit(local, 20)
    """

    process_group_count_result(send_query(query))
  end

  defp process_group_count_result(result) do
    result
    |> get_in(["@value"])
    |> List.first()
    |> get_in(["@value"])
    |> Enum.chunk_every(2)
    |> Enum.map(fn [name, %{"@value" => count}] ->
      {count, name}
    end)
  end
end

# HTTPoison.start()

# games that people like that like the games that I like (commonality)
# query = """
# g.V()
# .has('GamerAlias', 'skywalker123')
# .as('TargetGamer')
# .out('likes')
# .in('likes')
# .where(neq('TargetGamer'))
# .out('likes')
# .dedup()
# .values('GameTitle')
# """

# query = """
# g.V()
# .has('GamerAlias', 'skywalker123')
# .as('TargetGamer')
# .out('likes')
# .aggregate('self')
# .in('likes')
# .where(neq('TargetGamer'))
# .out('likes')
# .where(without('self'))
# .groupCount()
# .order(local)
# .by(values, desc)
# """

# query = """
# g.V().drop().iterate()
# """

# query = """
# g.V().hasLabel('user').count()
# """

# query = """
# g.V()
# .project('v','degree').by().by(bothE().count())
# .order().by('degree', desc)
# .limit(4)
# """

# query = """
# g.V('petition_24094912')
# .in('signed')
# .out('signed')
# .limit(10)
# """

# 20818498 - Pandemic Stimulus: Cancel Student Loans by Executive Order!
# 24284545 - Peter Dutton MP: Help Hitesh and family stay SAFE in Australia
# 22618924 - 17,463 - United Nations: Justice For Muslims in Chinese Concentration Camps
# 23159572 - 4,016 - Punjab wildlife And park management :A black bear at Bahria Orchard Zoo in Lahore is showing severe symptoms of Zoochosis
# 24539414 - 3,407 - artists: I want to make people think about poaching
# 24170860 - 3,261 - Victorian Premier Daniel Andrews: Allow people living alone through the pandemic to form a bubble
# 23510182 - 2,411 - Justin Trudeau: OPEN DOORS TO ALL INTERNATIONAL STUDENTS STARTING IN FALL 2020 INTO CANADA
# 24660708 - 1,476 - Tom Wolf: Stop the War on Bars and Restaurants
# 24432015 - 881 - Tony Evers: We Support Governor Evers of Wisconsin
# 24841538 - 681 - Plymouth City Council: Save Devils Point Swimming Pool
# 8762573 - 10 - Ban The Barbaric Slaughter Of Unstunned Animals In Australia
# 15847894 - 10- Robert Jenrick MP: Protect 117-125 Bayswater Road from Demolition
# query = """
# g.V('petition_24841538').as('source_petition')
# .in('signed')
# .out('signed').where(neq('source_petition'))
# .values('title')
# .timeLimit(1000)
# .groupCount()
# .order(local)
#   .by(values, desc)
# """

# pattern matching search
# query = """
# g.V()
# .match(
#   __.as('recruiter').out('recruited').
# )
# """

# 284472531 - 909 - 0
# 1039579815 - 908 - 0
# 1150407270 - 760 - 11
# user_id = 1_150_407_270

# # users I have recruited
# query = """
# g.V('user_#{user_id}')
# .out('recruited')
# .count()
# """

# # petitions I have signed
# query = """
# g.V('user_#{user_id}')
# .out('signed')
# .values('title')
# """

# __.as('recruiter').out('recruited').out('signed').as('recruitee_signed_petitions')
# __.as('recruiter').out('signed').as('recruiter_signed_petitions'),
# query = """
# g.V()
# .match( 
#   __.as('recruiter').hasId('user_#{user_id}'),
#   or(
#     __.as('recruiter').out('recruited').out('signed').as('recruitee_signed_petitions'),
#     __.as('recruiter').in('recruited').out('signed').as('recruitee_signed_petitions'),
#     __.as('recruiter').out('recruited').out('recruited').out('signed').as('recruitee_signed_petitions')
#   ),
#   __.not(__.as('recruitee_signed_petitions').in('signed').hasId('user_#{user_id}'))
# )
# .timeLimit(1000)
# .select('recruitee_signed_petitions')
# .values('title')
# .groupCount()
# .order(local)
#   .by(values, desc)
# .limit(local, 20)
# """

# __.not(__.as('cosigner_petitions').in('signed').hasId('user_#{user_id}'))
# __.as('recruiter').out('signed').in('signed').out('signed').as('cosigner_petitions') 
# query = """
# g.V()
# .match( 
#   __.as('subject').hasId('user_#{user_id}'),
#   __.as('subject').out('signed').as('subject_signed_petitions').timeLimit(1000),
#   __.as('subject_signed_petitions').in('signed').as('cosigners').timeLimit(1000),
#   __.as('cosigners').out('signed').as('cosigner_petitions').where(neq('subject_signed_petitions')).timeLimit(1000)
# )
# .timeLimit(1000)
# .select('cosigner_petitions')
# .values('title')
# .groupCount()
# .order(local)
#   .by(values, desc)
# .limit(local, 20)
# """

# petition_id = 24_719_105

# .where(neq('subject'))
# __.as('subject_signers').out('signed').as('subject_signers_petitions').timeLimit(1000),
# __.as('subject_signers_petitions').in('signed').as('subject_signers_petitions_signers')
# query = """
# g.V()
# .match( 
#   __.as('subject').hasId('petition_#{petition_id}'),
#   __.as('subject').in('signed').as('subject_signers').timeLimit(1000),
#   __.as('subject_signers').out('signed').where(neq('subject')).as('subject_signers_petitions').timeLimit(1000),
#   __.as('subject_signers_petitions').in('signed').as('subject_signers_petitions_signers')
# )
# .timeLimit(1000)
# .select('subject_signers_petitions')
# .values('title')
# .groupCount()
# .order(local)
#   .by(values, desc)
# .limit(local, 20)
# """

# IO.inspect(GremlinConsole.send_query(query))

# petition_id = 24_505_627
# petition_title = GremlinConsole.get_petition_title(petition_id)

# IO.puts("Source: #{petition_title}")

# GremlinConsole.petition_cosigner_petitions(petition_id)
# |> Enum.map(fn {count, petition_title} ->
#   IO.puts("#{count}, #{petition_title}")
# end)

# GremlinConsole.recruits_petitions(user_id)
# |> Enum.map(fn {count, petition_title} ->
#   IO.puts("#{count}, #{petition_title}")
# end)

# GremlinConsole.cosigner_petitions(user_id)
# |> Enum.map(fn {count, petition_title} ->
#   IO.puts("#{count}, #{petition_title}")
# end)

# petition_title = GremlinConsole.get_petition_title(petition_id)
# petition_signatures = GremlinConsole.get_petition_signatures(petition_id)
# IO.puts("Source: #{petition_title} (signed: #{petition_signatures})")
# signers = GremlinConsole.copetition_signers(petition_id)
# IO.puts("copetition signers: #{length(signers)} users")
# IO.puts("linking petitions: ")

# GremlinConsole.copetition_signers_linking_petitions(petition_id)
# |> Enum.map(fn {count, petition_title} ->
#   IO.puts("#{count}, #{petition_title}")
# end)
