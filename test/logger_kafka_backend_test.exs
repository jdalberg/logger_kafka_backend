defmodule LoggerKafkaBackendTest do
  use ExUnit.Case, async: false
  require Logger
  doctest LoggerKafkaBackend
  import TestHelpers

  @backend {LoggerKafkaBackend, :test_backend}

  Logger.add_backend @backend

  test "no trouble produce" do
    normal_start([{'b1',9092},{'b2',9092}], "log", 0) do
      home=self
      :meck.expect(:brod, :produce_sync, fn(_clientname, _topic, _partition, _key, output) ->
        # get the timestamp...
        dec=Poison.decode!(output)
        send home, {:produce_sync!,dec["time"]}
        :ok
      end)

      Logger.debug "foo"

      receive do
        {:produce_sync!, time} ->
          output="{\"time\": \"#{time}\", \"meta\": \"\", \"level\": \"debug\", \"message\": \"foo\"}"
          assert :meck.called(:brod, :produce_sync, [:lkb_bc, "log", 0, "LoggerKafkaBackend", output])
        err -> flunk( "Received something unexpected from :meck.produce_sync: #{inspect err}" )
      end
    end
  end

  test "produce with trouble, wrong topic" do
    # no matter what produce returns, we should have :ok from the GenEvent server
    normal_start([{'b1',9092},{'b2',9092}], "log", 0) do
      home=self
      :meck.expect(:brod, :produce_sync, fn(_clientname, _topic, _partition, _key, output) ->
        # get the timestamp...
        dec=Poison.decode!(output)
        send home, {:produce_sync!,dec["time"]}
        {:error,{:producer_not_found,"log"}} end)

      Logger.debug "foo"

      receive do
        {:produce_sync!, time} ->
          output="{\"time\": \"#{time}\", \"meta\": \"\", \"level\": \"debug\", \"message\": \"foo\"}"
          assert :meck.called(:brod, :produce_sync, [:lkb_bc, "log", 0, "LoggerKafkaBackend", output])
        err -> flunk( "Received something unexpected from :meck.produce_sync: #{inspect err}" )
      end

      assert last_error == "producer_not_found, wrong topic"
    end
  end

  test "produce with trouble, wrong partition" do
    # no matter what produce returns, we should have :ok from the GenEvent server
    normal_start([{'b1',9092},{'b2',9092}], "log", 0) do
      home=self
      :meck.expect(:brod, :produce_sync, fn(_clientname, _topic, _partition, _key, output) ->
        # get the timestamp...
        dec=Poison.decode!(output)
        send home, {:produce_sync!,dec["time"]}
        {:error,{:producer_not_found,"log",0}} end)

      Logger.debug "foo"

      receive do
        {:produce_sync!, time} ->
          output="{\"time\": \"#{time}\", \"meta\": \"\", \"level\": \"debug\", \"message\": \"foo\"}"
          assert :meck.called(:brod, :produce_sync, [:lkb_bc, "log", 0, "LoggerKafkaBackend", output])
        err -> flunk( "Received something unexpected from :meck.produce_sync: #{inspect err}" )
      end

      assert last_error == "producer_not_found, wrong partition"
    end
  end

  test "produce with trouble, client down" do
    # no matter what produce returns, we should have :ok from the GenEvent server
    normal_start([{'b1',9092},{'b2',9092}], "log", 0) do
      home=self
      :meck.expect(:brod, :produce_sync, fn(_clientname, _topic, _partition, _key, output) ->
        # get the timestamp...
        dec=Poison.decode!(output)
        send home, {:produce_sync!,dec["time"]}
        {:error,:client_down} end)

      Logger.debug "foo"

      receive do
        {:produce_sync!, time} ->
          output="{\"time\": \"#{time}\", \"meta\": \"\", \"level\": \"debug\", \"message\": \"foo\"}"
          assert :meck.called(:brod, :produce_sync, [:lkb_bc, "log", 0, "LoggerKafkaBackend", output])
        err -> flunk( "Received something unexpected from :meck.produce_sync: #{inspect err}" )
      end

      assert last_error == "client down"
    end
  end

  test "error in configure, bad brokers" do
    :meck.new(:brod)

    :meck.expect(:brod, :start_client, fn(_brokers, _clientname, _options) -> :ok end)

    :meck.expect(:brod, :start_producer, fn(_clientname, _topic, _options) -> {:error, :client_down} end)

    c=config [brokers: [{'b1',9092}], topic: "foo", partition: 42]

    assert :meck.called(:brod, :start_client, [[{'b1',9092}], :lkb_bc, [reconnect_cool_down_seconds: 10]])
    assert :meck.called(:brod, :start_producer, [:lkb_bc, "foo", []])

    assert c=={:error, :client_down}

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

  defp last_error do
    {:ok, err} = GenEvent.call(Logger, @backend, :last_error)
    err
  end

  defp config(opts) do
    Logger.configure_backend(@backend, opts)
  end
end
