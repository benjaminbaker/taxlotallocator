defmodule TaxLotAllocator.Data.TaxLot do
  @moduledoc """
  This module is responsible for performing CRUD operations for Tax Lots, and
  converting a Tax Lot to a printable string.

  The price is the weighted average of all of the price/quantity combos from
  the transactions that comprise it. 

  To compute the weighted average, Half Even rounding is used to round fractional cents
  so as to not have a rounding bias whenever the weighted average fractional cents equal 
  0.5
  """

  use TypedStruct

  typedstruct do
    field :id, Integer.t(), enforce: true
    field :date, Date.t(), enforce: true
    field :price, Decimal, enforce: true
    field :quantity, Decimal, enforce: true
  end

  @spec create_tax_lot(id :: Integer.t(), date :: Date.t(), transactions :: []) ::
          {:ok, %__MODULE__{}}
  def create_tax_lot(id, date, transactions) do
    {total_price, total_quantity} = compute_total_price_and_quantity(transactions)
    price_weighted_average = compute_half_even_weighted_average(total_price, total_quantity)

    tax_lot = %__MODULE__{
      id: id,
      date: date,
      price: price_weighted_average,
      quantity: total_quantity
    }

    {:ok, tax_lot}
  end

  @doc "Visible for test only. DO NOT USE"
  @spec compute_total_price_and_quantity(transactions :: []) ::
          {Decimal.t(), Decimal.t()}
  def compute_total_price_and_quantity(transactions) do
    transactions
    |> Enum.reduce({Decimal.new("0.00000000"), Decimal.new("0.00000000")}, fn transaction,
                                                                              {total_price,
                                                                               total_quantity} ->
      weighted_price = Decimal.mult(transaction.price, transaction.quantity) |> Decimal.round(8)

      new_total_price = Decimal.add(total_price, weighted_price)
      new_total_quantity = Decimal.add(total_quantity, transaction.quantity)
      {new_total_price, new_total_quantity}
    end)
  end

  @doc "Visible for test only. DO NOT USE"
  @spec compute_half_even_weighted_average(
          total_price :: Decimal.t(),
          total_quantity :: Decimal.t()
        ) ::
          Decimal.t()
  def compute_half_even_weighted_average(total_price, total_quantity) do
    total_price
    |> Decimal.div(total_quantity)
    |> Decimal.round(2, :half_even)
  end

  @spec update_tax_lot(tax_lot :: %__MODULE__{}, update_params :: %{}) ::
          {:ok, %__MODULE__{}} | {:error, String.t()}
  def update_tax_lot(%__MODULE__{} = tax_lot, %{} = update_params) do
    case update_params do
      %{id: _id} ->
        {:error, "Cannot update tax lot id"}

      %{date: _date} ->
        {:error, "Cannot update tax lot date"}

      %{price: _price} ->
        {:error, "Cannot update tax lot price"}

      _ ->
        updated_tax_lot = tax_lot |> Map.merge(update_params)
        {:ok, updated_tax_lot}
    end
  end

  @spec convert_tax_lot_to_string(transaction :: %__MODULE__{}) :: String.t()
  def convert_tax_lot_to_string(%__MODULE__{id: id, date: date, price: price, quantity: quantity}) do
    id_string = Integer.to_string(id)
    date_string = Date.to_string(date)
    price_string = Decimal.to_string(price)
    quantity_string = Decimal.to_string(quantity)

    id_string <> "," <> date_string <> "," <> price_string <> "," <> quantity_string
  end
end
