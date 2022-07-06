defmodule TaxLotAllocator.Data.Transaction do
  @moduledoc """
  This module is responsible for performing CRUD operations for Transactions, and
  validating that stdio transaction creation inputs are valid.
  """

  use TypedStruct

  typedstruct do
    field :date, Date.t(), enforce: true
    field :transaction_type, :buy | :sell, enforce: true
    field :price, Decimal, enforce: true
    field :quantity, Decimal, enforce: true
  end

  # TODO: write quantity and price validators more cleanly 

  @doc "Visible for test only. DO NOT USE"
  @spec validate_date(date_string :: String.t()) :: {:ok, Date.t()} | {:error, String.t()}
  def validate_date(date_string) do
    date_string
    |> String.trim()
    |> Date.from_iso8601()
    |> case do
      {:ok, date} ->
        {:ok, date}

      {:error, :invalid_format} ->
        {:error, "The date provided is in an invalid format, it must be YYYY-MM-DD."}

      {:error, :invalid_date} ->
        {:error, "The date provided is not an actual date."}
    end
  end

  @doc "Visible for test only. DO NOT USE"
  @spec validate_transaction_type(transaction_type_string :: String.t()) ::
          {:ok, :buy | :sell} | {:error, String.t()}
  def validate_transaction_type(transaction_type_string) do
    transaction_type_string
    |> String.trim()
    |> case do
      transaction_type_string when transaction_type_string in ["buy", "sell"] ->
        {:ok, String.to_atom(transaction_type_string)}

      _transaction_type_string ->
        {:error, "The transaction type given is invalid, it must be buy or sell."}
    end
  end

  @doc "Visible for test only. DO NOT USE"
  @spec validate_price(price_string :: String.t()) :: {:ok, Decimal.t()} | {:error, String.t()}
  def validate_price(price_string) do
    trimmed_price_string = String.trim(price_string)

    if String.match?(trimmed_price_string, ~r/^[0-9]*\.[0-9]{2}$/) do
      decimal_price = Decimal.new(trimmed_price_string)
      zero = Decimal.new("0")

      if Decimal.eq?(zero, decimal_price) do
        {:error, "The price cannot equal 0."}
      else
        {:ok, decimal_price}
      end
    else
      {:error, "The price given is invalid, it must be positive and have two decimal places."}
    end
  end

  @doc "Visible for test only. DO NOT USE"
  @spec validate_quantity(quantity_string :: String.t()) ::
          {:ok, Decimal.t()} | {:error, String.t()}
  def validate_quantity(quantity_string) do
    trimmed_quantity_string = String.trim(quantity_string)

    if String.match?(trimmed_quantity_string, ~r/^[0-9]*\.[0-9]{8}$/) do
      decimal_quantity = Decimal.new(trimmed_quantity_string)
      zero = Decimal.new("0")

      if Decimal.eq?(zero, decimal_quantity) do
        {:error, "The quantity cannot equal 0."}
      else
        {:ok, decimal_quantity}
      end
    else
      {:error, "The quantity is invalid, it must be a positive number with eight decimal places."}
    end
  end

  @spec create_transaction(%{
          date: date :: String.t(),
          transaction_type: transaction_type :: String.t(),
          price: price :: String.t(),
          quantity: quantity :: String.t()
        }) ::
          {:ok, %__MODULE__{}} | {:error, String.t()}
  def create_transaction(%{
        date: date_string,
        transaction_type: transaction_type_string,
        price: price_string,
        quantity: quantity_string
      }) do
    with {:ok, date} <- validate_date(date_string),
         {:ok, transaction_type} <- validate_transaction_type(transaction_type_string),
         {:ok, price} <- validate_price(price_string),
         {:ok, quantity} <- validate_quantity(quantity_string) do
      transaction = %__MODULE__{
        date: date,
        transaction_type: transaction_type,
        price: price,
        quantity: quantity
      }

      {:ok, transaction}
    end
  end

  @spec order_by_transaction_type(
          transaction_type_1 :: :buy | :sell,
          transaction_type_2 :: :buy | :sell
        ) ::
          :eq | :gt | :lt
  def order_by_transaction_type(transaction_type_1, transaction_type_2)
      when transaction_type_1 == transaction_type_2,
      do: :eq

  def order_by_transaction_type(:buy, :sell), do: :gt
  def order_by_transaction_type(:sell, :buy), do: :lt

  @spec update_transaction(transaction :: %__MODULE__{}, update_params :: %{}) ::
          {:ok, %__MODULE__{}} | {:error, String.t()}
  def update_transaction(%__MODULE__{} = transaction, %{} = update_params) do
    case update_params do
      %{date: _date} ->
        {:error, "Cannot update transaction date"}

      %{transaction_type: _transaction_type} ->
        {:error, "Cannot update transaction transaction type"}

      %{price: _price} ->
        {:error, "Cannot update transaction price"}

      _ ->
        updated_transaction = transaction |> Map.merge(update_params)
        {:ok, updated_transaction}
    end
  end
end
