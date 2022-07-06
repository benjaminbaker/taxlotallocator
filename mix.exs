defmodule TaxLotAllocator.MixProject do
  use Mix.Project

  def project do
    [
      app: :tasklotallocator,
      version: "0.1.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  defp escript do
    [main_module: TaxLotAllocator]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:decimal, "~> 2.0"},
      {:ex_machina, "~> 2.7.0"},
      {:psq, "~> 0.1.0"},
      {:typed_struct, "~> 0.1.4"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
