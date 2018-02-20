defmodule LoggerKafkaBackend.Mixfile do
  use Mix.Project

  def project do
    [app: :logger_kafka_backend,
     version: "0.1.13",
     elixir: "~> 1.6",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    [applications: [:brod, :logger]]
  end

  defp deps do
    [
     {:brod, "~> 2.3.3"},
     {:poison, "~> 2.0"},
     {:meck, "~> 0.8.2", only: :test}, # To make test emulate calls to brod
     {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    A backend for Logger that logs to Kafka using Brod
    """
  end

  defp package do
    [
      name: :logger_kafka_backend,
      files: ["lib", "mix.exs", "README*", "CHANGELOG*"],
      maintainers: ["Jesper Dalberg"],
      licenses: ["Artistic"],
      links: %{"GitHub" => "https://github.com/jdalberg/logger_kafka_backend"}
    ]
  end

end
