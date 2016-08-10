defmodule LoggerKafkaBackend do
  @moduledoc"""
  """

  use GenEvent

  @type brokers   :: [String.t]
  @type format    :: String.t
  @type level     :: Logger.level
  @type metadata  :: [atom]


  @default_format "$metadata[$date $time] $level: $message"

  def init({__MODULE__, name}) do
    configure(name, [])
  end

  def handle_call({:configure, opts}, %{name: name} = state) do
    {err,state} = configure(name, opts, state)
    {:ok, err, state}
  end

  # returns the configured brokers
  def handle_call(:brokers, %{brokers: brokers} = state) do
    {:ok, {:ok, brokers}, state}
  end

  # returns the configured topic
  def handle_call(:topic, %{topic: topic} = state) do
    {:ok, {:ok, topic}, state}
  end

  # returns the configured partition
  def handle_call(:partition, %{partition: partition} = state) do
    {:ok, {:ok, partition}, state}
  end

  # returns the configured use_json setting
  def handle_call(:partition, %{use_json: use_json} = state) do
    {:ok, {:ok, use_json}, state}
  end

  # returns the last error registered from Kafka
  def handle_call(:last_error, %{last_error: err} = state) do
    {:ok, {:ok, err}, state}
  end

  def handle_event({_level, gl, {Logger, _, _, _}}, state)
    when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level, metadata_filter: metadata_filter} = state) do
    if (is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt) and metadata_matches?(md, metadata_filter) do
      log_event(level, msg, ts, md, state)
    else
      {:ok, state}
    end
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end


  # helpers

  defp log_event(_level, _msg, _ts, _md, %{brokers: nil} = state) do
    {:ok, state}
  end

  defp log_event(_level, _msg, _ts, _md, %{topic: nil} = state) do
    {:ok, state}
  end

  defp log_event(level, msg, ts, md, %{brokers: brokers, topic: topic, partition: partition} = state) when is_list(brokers) and is_binary(topic) and is_integer(partition) do
    if length(brokers)>0 and topic != "" do
      output = if state.use_json do
        timestamp = case ts do
          {date,time} -> "#{Logger.Utils.format_date(date)} #{Logger.Utils.format_time(time)}"
          _ -> "NA"
        end
        Poison.encode!(%{time: timestamp, meta: Enum.into(take_metadata(md, state.metadata), %{}), level: level, message: msg})
      else
        format_event(level, msg, ts, md, state)
      end
      # keys? - better than "LoggerKafkaBackend"...
      case :brod.produce_sync(:lkb_bc,state.topic,state.partition,"LoggerKafkaBackend",to_string(output)) do
        {:error, {:producer_not_found, _topic}} -> {:ok, %{state | last_error: "producer_not_found, wrong topic"}}
        {:error, {:producer_not_found, _topic, _partition}} -> {:ok, %{state | last_error: "producer_not_found, wrong partition"}}
        {:error, :client_down} -> {:ok, %{state | last_error: "client down"}}
        _ -> {:ok, %{state | last_error: nil}}
      end
    else
      log_event(level, msg, ts, md, %{state | brokers: nil})
    end
  end

  defp log_event(level, msg, ts, md, %{brokers: brokers, topic: topic} = state) when is_list(brokers) and is_binary(topic) do
    if length(brokers)>0 and topic != "" do
     log_event(level, msg, ts, md, %{state | partition: 0})
    else
     log_event(level, msg, ts, md, %{brokers: nil})
    end
  end

  defp format_event(level, msg, ts, md, %{format: format, metadata: keys}) do
    Logger.Formatter.format(format, level, msg, ts, take_metadata(md, keys))
  end

  @doc false
  @spec metadata_matches?(Keyword.t, nil|Keyword.t) :: true|false
  def metadata_matches?(_md, nil), do: true
  def metadata_matches?(_md, []), do: true # all of the filter keys are present
  def metadata_matches?(md, [{key, val}|rest]) do
    case Keyword.fetch(md, key) do
      {:ok, ^val} ->
        metadata_matches?(md, rest)
      _ -> false #fail on first mismatch
    end
  end

  defp take_metadata(metadata, keys) do
    metadatas = Enum.reduce(keys, [], fn key, acc ->
      case Keyword.fetch(metadata, key) do
        {:ok, val} -> [{key, val} | acc]
        :error     -> acc
      end
    end)

    Enum.reverse(metadatas)
  end


  defp configure(name, opts) do
    state = %{name: nil, brokers: [], last_error: nil, topic: nil, partition: nil, format: nil, level: nil, metadata: nil, metadata_filter: nil, use_json: false}
    configure(name, opts, state)
  end

  defp configure(name, opts, state) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    level           = Keyword.get(opts, :level)
    metadata        = Keyword.get(opts, :metadata, [])
    format_opts     = Keyword.get(opts, :format, @default_format)
    format          = Logger.Formatter.compile(format_opts)
    brokers         = Keyword.get(opts, :brokers)
    topic           = Keyword.get(opts, :topic)
    partition       = Keyword.get(opts, :partition, 0)
    metadata_filter = Keyword.get(opts, :metadata_filter)
    use_json        = Keyword.get(opts, :use_json, true)

    {eb,le}=case brokers do
      nil -> {[],:ok} # configure with no brokers is ok.
      brokers when is_list(brokers) and length(brokers) > 0 ->
        erl_brokers=Enum.map(brokers,fn(e) -> {to_char_list(elem(e,0)),elem(e,1)} end)
        last_error=if topic != nil do
          case :brod.start_client(erl_brokers, :lkb_bc, [{:reconnect_cool_down_seconds, 10}]) do # TODO: make client options configurable
            :ok -> # start a producer on it, should always be ok...
              :brod.start_producer(:lkb_bc, to_string(topic), []) # TODO: make producer options configurable
            {:error, {:already_started,_pid}} -> # restart client with new brokerlist
              :brod.stop_client( :lkb_bc )
              case :brod.start_client(erl_brokers, :lkb_bc, [{:reconnect_cool_down_seconds, 10}]) do
                :ok -> :brod.start_producer(:lkb_bc, to_string(topic), []) # TODO: make producer options configurable
                err -> err
              end
            err -> err
          end
        else
          :ok # topic is nil, which is :ok to configure.
        end
        {erl_brokers,last_error}
      _-> {[],{:error,"unknown format of the brokers configutionation parameter"}}
    end

    {le,%{state | name: name, brokers: eb, topic: to_string(topic), partition: partition, last_error: le, format: format, level: level, metadata: metadata, metadata_filter: metadata_filter, use_json: use_json}}
  end

end
