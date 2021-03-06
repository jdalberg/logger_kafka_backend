# LoggerKafkaBackend
[![Build Status](https://travis-ci.org/jdalberg/logger_kafka_backend.svg?branch=master)](https://travis-ci.org/jdalberg/logger_kafka_backend)
[![Hex.pm Version](http://img.shields.io/hexpm/v/logger_kafka_backend.svg?style=flat)](https://hex.pm/packages/logger_kafka_backend)

A backend for the Elixir `Logger` module that speaks Apache Kafka. It relies on the
erland `brod` module to do the actual Kafka integration.

The code has used the `LoggerFileBackend` (https://github.com/onkel-dirtus/logger_file_backend) as
inspiration.

## Configuration

Our config.exs would have an entry similar to this:

```elixir
# tell logger to load a LoggerKafkaBackend processes
config :logger,
  backends: [{LoggerKafkaBackend, :kafka_logger}]

# configuration for the {LoggerKafkaBackend, :kafka_logger} backend
config :logger, :kafka_logger,
  brokers: [{"broker1", 9092}, {"broker2", 9092}],
  topic: "my_log_topic",
  partition: 0,
  metadata: [:foo],
  level: :error,
  log_hostname: true

```

The `metadata` denotes which keys from the process metadata we want in the log
format, so we can get the ones we are interested in and nothing more.

This tells Logger to use the LoggerKafkaBackend as the backend and tells the backend
how to integrate with Apache Kafka.

The default logging format is a simple JSON structure, containing time, level and message and metadata, and possible host.


