defmodule LoggerKafkaBackend.Mixfile do
  use Mix.Project

  def project do
    [app: :logger_kafka_backend,
     version: "0.1.10",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger, :brod]]
  end

  defp deps do
    [
     {:brod, "~> 2.3.3"},
     {:poison, "~> 2.0"},
     {:meck, "~> 0.8.2", only: :test} # To make test emulate calls to brod
    ]
  end
end
