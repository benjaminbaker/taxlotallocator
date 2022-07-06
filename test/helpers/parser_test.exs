defmodule TaxLotAllocator.Helpers.ParserTest do
  use ExUnit.Case
  doctest TaxLotAllocator.Helpers.Parser

  alias TaxLotAllocator.Helpers.Parser

  describe "parse_transactions_from_input" do
    test "works with newline breaks" do
      input =
        "2021-01-01,buy,10000.00,1.00000000\n2021-01-02,buy,20000.00,1.00000000\n2021-02-01,sell,20000.00,1.50000000"

      transaction_list = Parser.parse_transactions_from_input(input)

      assert transaction_list == [
               "2021-01-01,buy,10000.00,1.00000000",
               "2021-01-02,buy,20000.00,1.00000000",
               "2021-02-01,sell,20000.00,1.50000000"
             ]
    end

    test "removes newline character from the end of the input" do
      input = "2021-01-01,buy,10000.00,1.00000000\n"

      transaction_list = Parser.parse_transactions_from_input(input)

      assert transaction_list == [
               "2021-01-01,buy,10000.00,1.00000000"
             ]
    end

    test "works for empty input" do
      assert [] == Parser.parse_transactions_from_input("")
    end
  end

  describe "parse_transaction" do
    test "correctly parses transaction into struct" do
      {:ok, %{date: date, transaction_type: transaction_type, price: price, quantity: quantity}} =
        Parser.parse_transaction("2021-01-01,buy,10000.00,1.00000000")

      assert date == "2021-01-01"
      assert transaction_type == "buy"
      assert price == "10000.00"
      assert quantity == "1.00000000"
    end

    test "returns error when transaction has too many arguments" do
      {:error, "There are an invalid number of fields supplied to create a transaction."} =
        Parser.parse_transaction("2021-01-01,buy,10000.00,1.00000000,4")
    end

    test "returns error when transaction has too few arguments" do
      {:error, "There are an invalid number of fields supplied to create a transaction."} =
        Parser.parse_transaction("2021-01-01,buy,10000.00")
    end

    test "returns error when transaction has no arguments" do
      {:error, "There are an invalid number of fields supplied to create a transaction."} =
        Parser.parse_transaction("")
    end
  end

  describe "validate_tax_lot_selection_algorithm" do
    test "fifo is valid" do
      {:ok, :fifo} = Parser.validate_tax_lot_selection_algorithm("fifo")
    end

    test "hifo is valid" do
      {:ok, :hifo} = Parser.validate_tax_lot_selection_algorithm("hifo")
    end

    test "returns error for invalid algorithm" do
      {:error, "Invalid tax lot selction algorithm, it must be fifo or hifo."} =
        Parser.validate_tax_lot_selection_algorithm("lifo")
    end
  end
end
