defmodule TaxLotAllocator.Helpers.Parser do
  @moduledoc """
  The Parser module is responsible for validating and parsing stdio and arguments
  passed into the TaxLotAllocator script. 

  It parse stdio input into transaction inputs and transaction creation parameters.
  """

  @spec parse_transactions_from_input(standard_input :: String.t()) ::
          [String.t()]
  def parse_transactions_from_input(""), do: []

  def parse_transactions_from_input(standard_input) do
    standard_input
    |> String.trim("\n")
    |> String.split("\n")
  end

  @spec parse_transaction(transaction_string :: String.t()) ::
          {:ok, %{}} | {:error, String.t()}
  def parse_transaction(transaction_string) do
    case String.split(transaction_string, ",") do
      [date, transaction_type, price, quantity] ->
        transaction_creation_params = %{
          date: date,
          transaction_type: transaction_type,
          price: price,
          quantity: quantity
        }

        {:ok, transaction_creation_params}

      _transaction_fields ->
        {:error, "There are an invalid number of fields supplied to create a transaction."}
    end
  end

  @spec validate_tax_lot_selection_algorithm(algorithm_string :: String.t()) ::
          {:ok, :fifo | :hifo} | {:error, String.t()}
  def validate_tax_lot_selection_algorithm(algorithm_string) do
    case algorithm_string do
      algorithm when algorithm in ["fifo", "hifo"] ->
        {:ok, String.to_atom(algorithm)}

      _ ->
        {:error, "Invalid tax lot selction algorithm, it must be fifo or hifo."}
    end
  end
end
