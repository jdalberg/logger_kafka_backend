defmodule LoggerKafkaBackendTest do
  use ExUnit.Case, async: false
  require Logger
  doctest LoggerKafkaBackend

  @backend {LoggerKafkaBackend, :test}

  Logger.add_backend @backend

  test "no trouble produce" do
    home = self

    :meck.new(:brod)

    :meck.expect(:brod, :start_client, fn(_brokers, _clientname, _options) ->
      send home, :start_client!
      :ok
      end)

    :meck.expect(:brod, :start_producer, fn(_clientname, _topic, _options) ->
      send home, :start_producer!
      :ok
      end)

    config [brokers: ["b1","b2"], topic: "log", partition: 0]

    assert_receive :start_client!, 10
    assert_receive :start_producer!, 10

    assert brokers == ["b1","b2"]
    assert topic == "log"
    assert partition == 0

    # iex(18)> {:ok, callref}=:brod.produce(:brod_client_2,"dev.log.acs4",0,"testkey","testval")          
    # {:ok, {:brod_call_ref, #PID<0.130.0>, #PID<0.242.0>, #Reference<0.0.6.512>}}

    :meck.expect(:brod, :produce, fn(_clientname, _topic, _partition, _key, _output) ->
      send home, :called!
      {:ok,{:brod_call_ref,:foo,:bar,:ref}} end)

    Logger.debug "foo"

    assert_receive :called!, 10;

    :meck.unload(:brod)
  end

  defp brokers do
    {:ok, brokers} = GenEvent.call(Logger, @backend, :brokers)
    brokers
  end

  defp topic do
    {:ok, topic} = GenEvent.call(Logger, @backend, :topic)
    topic
  end

  defp partition do
    {:ok, partition} = GenEvent.call(Logger, @backend, :partition)
    partition
  end

  defp config(opts) do
    Logger.configure_backend(@backend, opts)
  end
end
