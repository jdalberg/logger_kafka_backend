:application.start :logger
ExUnit.start()

defmodule TestHelpers do
  defmacro normal_start(brokers, topic, partition, do: body) do
    quote do
      :meck.new(:brod)

      :meck.expect(:brod, :start_client, fn(_brokers, _clientname, _options) -> :ok end)

      :meck.expect(:brod, :start_producer, fn(_clientname, _topic, _options) -> :ok end)

      config [brokers: unquote(brokers), topic: unquote(topic), partition: unquote(partition)]

      assert :meck.called(:brod, :start_client, [unquote(brokers), :lkb_bc, [reconnect_cool_down_seconds: 10]])
      assert :meck.called(:brod, :start_producer, [:lkb_bc, unquote(topic), []])

      assert brokers() == unquote(brokers)
      assert topic() == unquote(topic)
      assert partition() == unquote(partition)

      unquote(body)

      :meck.unload(:brod)
    end
  end
end
