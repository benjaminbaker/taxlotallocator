defmodule TaxLotAllocator.Factory do
  use ExMachina

  alias TaxLotAllocator.Data.{
    TaxLot,
    Transaction
  }

  def transaction_factory(args) do
    {:ok, date} = Date.from_iso8601("2021-01-01")
    price = "2.00" |> Decimal.new() |> Decimal.round(2)
    quantity = "1.00000000" |> Decimal.new() |> Decimal.round(8)

    %Transaction{date: date, transaction_type: :buy, price: price, quantity: quantity}
    |> Map.merge(args)
  end

  def tax_lot_factory(args) do
    {:ok, date} = Date.from_iso8601("2021-01-01")
    price = "2.00" |> Decimal.new() |> Decimal.round(2)
    quantity = "1.00000000" |> Decimal.new() |> Decimal.round(8)

    %TaxLot{id: 1, date: date, price: price, quantity: quantity}
    |> Map.merge(args)
  end
end
