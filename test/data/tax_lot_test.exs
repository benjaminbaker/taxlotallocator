defmodule TaxLotAllocator.Data.TaxLotTest do
  use ExUnit.Case
  doctest TaxLotAllocator.Data.TaxLot

  import TaxLotAllocator.Factory

  alias TaxLotAllocator.Data.TaxLot

  describe "create_tax_lot" do
    test "returns expected TaxLot typedstruct" do
      input_id = 1
      {:ok, input_date} = Date.from_iso8601("2021-01-01")
      input_transaction = build(:transaction)
      expected_price = input_transaction.price
      expected_quantity = input_transaction.quantity

      {:ok, %TaxLot{id: id, date: date, price: price, quantity: quantity}} =
        TaxLot.create_tax_lot(input_id, input_date, [input_transaction])

      assert id == input_id
      assert date == input_date
      assert price == expected_price
      assert quantity == expected_quantity
    end
  end

  describe "compute_total_price_and_quantity" do
    test "works for several transactions" do
      transaction_1 =
        build(:transaction, price: Decimal.new("5.0"), quantity: Decimal.new("1.00000000"))

      transaction_2 =
        build(:transaction, price: Decimal.new("3.0"), quantity: Decimal.new("2.00000000"))

      transaction_3 =
        build(:transaction, price: Decimal.new("7.0"), quantity: Decimal.new("4.00000000"))

      transactions = [transaction_1, transaction_2, transaction_3]

      total_price = Decimal.new("39.00000000")
      total_quantity = Decimal.new("7.00000000")

      assert {total_price, total_quantity} ==
               TaxLot.compute_total_price_and_quantity(transactions)
    end

    test "works for no transactions" do
      transactions = []

      total_price = Decimal.new("0.00000000")
      total_quantity = Decimal.new("0.00000000")

      assert {total_price, total_quantity} ==
               TaxLot.compute_total_price_and_quantity(transactions)
    end
  end

  describe "compute_half_even_weighted_average" do
    test "works for regular division" do
      total_price = Decimal.new("4.00")
      total_quantity = Decimal.new("2.00")
      weighted_average = Decimal.new("2.00")

      assert weighted_average ==
               TaxLot.compute_half_even_weighted_average(total_price, total_quantity)
    end

    test "rounds to two decimal places" do
      total_price = Decimal.new("5.00")
      total_quantity = Decimal.new("3.00")
      weighted_average = Decimal.new("1.67")

      assert weighted_average ==
               TaxLot.compute_half_even_weighted_average(total_price, total_quantity)
    end

    test "implements half even rounding at two decimal places" do
      # Rounds up when the second decimal place is odd and third is 5
      total_price = Decimal.new("25.55")
      total_quantity = Decimal.new("10.00")
      weighted_average = Decimal.new("2.56")

      assert weighted_average ==
               TaxLot.compute_half_even_weighted_average(total_price, total_quantity)

      # Rounds down when the second decimal place is even and third is 5
      total_price = Decimal.new("24.45")
      total_quantity = Decimal.new("10.00")
      weighted_average = Decimal.new("2.44")

      assert weighted_average ==
               TaxLot.compute_half_even_weighted_average(total_price, total_quantity)
    end
  end

  describe "update_tax_lot" do
    test "updates quantity" do
      tax_lot = build(:tax_lot)
      new_quantity = Decimal.new("100.00000000")

      {:ok, %TaxLot{quantity: quantity}} =
        TaxLot.update_tax_lot(tax_lot, %{quantity: new_quantity})

      assert Decimal.equal?(quantity, new_quantity)
    end

    test "throws error when attempting to update id" do
      tax_lot = build(:tax_lot)

      {:error, "Cannot update tax lot id"} = TaxLot.update_tax_lot(tax_lot, %{id: 2})
    end

    test "throws error when attempting to update date" do
      tax_lot = build(:tax_lot)

      {:error, "Cannot update tax lot date"} =
        TaxLot.update_tax_lot(tax_lot, %{date: Date.from_iso8601("2022-02-02")})
    end

    test "throws error when attempting to update price" do
      tax_lot = build(:tax_lot)

      {:error, "Cannot update tax lot price"} =
        TaxLot.update_tax_lot(tax_lot, %{price: Decimal.new("5.00")})
    end
  end

  describe "convert_tax_lot_to_string" do
    test "works" do
      tax_lot = build(:tax_lot)

      assert "1,2021-01-01,2.00,1.00000000" == TaxLot.convert_tax_lot_to_string(tax_lot)
    end
  end
end
