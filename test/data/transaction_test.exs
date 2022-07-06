defmodule TaxLotAllocator.Data.TransactionTest do
  use ExUnit.Case
  doctest TaxLotAllocator.Data.Transaction

  import TaxLotAllocator.Factory

  alias TaxLotAllocator.Data.Transaction

  describe "validate_date" do
    test "returns ok for YYYY-MM-DD date" do
      {:ok, ~D[2021-01-01]} = Transaction.validate_date("2021-01-01")
    end

    test "trims leading and trailing spaces" do
      {:ok, ~D[2021-01-01]} = Transaction.validate_date(" 2021-01-01 ")
    end

    test "returns error for MM-DD-YYYY date" do
      {:error, "The date provided is in an invalid format, it must be YYYY-MM-DD."} =
        Transaction.validate_date("01-01-2021")
    end

    test "returns error for corrupt date" do
      {:error, "The date provided is in an invalid format, it must be YYYY-MM-DD."} =
        Transaction.validate_date("202-01-01")
    end

    test "returns error for out-of-range date" do
      {:error, "The date provided is not an actual date."} =
        Transaction.validate_date("2021-01-32")
    end
  end

  describe "validate_transaction_type" do
    test "returns true for buy" do
      {:ok, :buy} = Transaction.validate_transaction_type("buy")
    end

    test "returns true for sell" do
      {:ok, :sell} = Transaction.validate_transaction_type("sell")
    end

    test "trims leading and trailing spaces" do
      {:ok, :sell} = Transaction.validate_transaction_type(" sell ")
    end

    test "returns true for anything else" do
      {:error, "The transaction type given is invalid, it must be buy or sell."} =
        Transaction.validate_transaction_type("asdf")
    end
  end

  describe "validate_price" do
    test "returns valid price" do
      expected_decimal_price = Decimal.new("1.00")
      {:ok, ^expected_decimal_price} = Transaction.validate_price("1.00")
    end

    test "trims leading and trailing spaces" do
      expected_decimal_price = Decimal.new("1.00")
      {:ok, ^expected_decimal_price} = Transaction.validate_price(" 1.00 ")
    end

    test "returns error for zero quantity" do
      {:error, "The price cannot equal 0."} = Transaction.validate_price("0.00")
    end

    for {price_input, error_reason} <- [
          {"-1.00", "negative price"},
          {"100", "integer price"},
          {"1.000", "number with more than two decimal places"},
          {"abc", "letters"}
        ] do
      test "returns error for #{error_reason}" do
        price_input = unquote(price_input)

        {:error, "The price given is invalid, it must be positive and have two decimal places."} =
          Transaction.validate_price(price_input)
      end
    end
  end

  describe "validate_quantity" do
    test "returns valid quantity" do
      expected_decimal_quantity = Decimal.new("1.00000000")
      {:ok, ^expected_decimal_quantity} = Transaction.validate_quantity("1.00000000")
    end

    test "trims leading and trailing spaces" do
      expected_decimal_quantity = Decimal.new("1.00000000")
      {:ok, ^expected_decimal_quantity} = Transaction.validate_quantity(" 1.00000000 ")
    end

    test "returns error for zero quantity" do
      {:error, "The quantity cannot equal 0."} = Transaction.validate_quantity("0.00000000")
    end

    for {quantity_input, error_reason} <- [
          {"-1.00", "negative quantity"},
          {"100", "integer quantity"},
          {"1.000000000", "quantity with more than eight decimal places"},
          {"abc", "letters"}
        ] do
      test "returns error for #{error_reason}" do
        quantity_input = unquote(quantity_input)

        {:error,
         "The quantity is invalid, it must be a positive number with eight decimal places."} =
          Transaction.validate_quantity(quantity_input)
      end
    end
  end

  describe "create_transaction" do
    test "creates transaction module from string attributes" do
      date_string = "2021-01-01"
      transaction_type_string = "buy"
      price_string = "10000.00"
      quantity_string = "1.00000000"

      {:ok,
       %Transaction{
         date: date,
         transaction_type: transaction_type,
         price: price,
         quantity: quantity
       }} =
        Transaction.create_transaction(%{
          date: date_string,
          transaction_type: transaction_type_string,
          price: price_string,
          quantity: quantity_string
        })

      assert {:ok, date} == Date.from_iso8601(date_string)
      assert transaction_type == :buy
      assert price == Decimal.new(price_string)
      assert quantity == Decimal.new(quantity_string)
    end

    test "returns error if date_string is invalid" do
      date_string = "2021-01-33"
      transaction_type_string = "buy"
      price_string = "10000.00"
      quantity_string = "1.00000000"

      {:error, error_message} =
        Transaction.create_transaction(%{
          date: date_string,
          transaction_type: transaction_type_string,
          price: price_string,
          quantity: quantity_string
        })

      assert error_message == "The date provided is not an actual date."
    end

    test "returns error if transaction_type is invalid" do
      date_string = "2021-01-01"
      transaction_type_string = "rent"
      price_string = "10000.00"
      quantity_string = "1.00000000"

      {:error, error_message} =
        Transaction.create_transaction(%{
          date: date_string,
          transaction_type: transaction_type_string,
          price: price_string,
          quantity: quantity_string
        })

      assert error_message == "The transaction type given is invalid, it must be buy or sell."
    end

    test "returns error if price_string is invalid" do
      date_string = "2021-01-01"
      transaction_type_string = "buy"
      price_string = "10000"
      quantity_string = "1.00000000"

      {:error, error_message} =
        Transaction.create_transaction(%{
          date: date_string,
          transaction_type: transaction_type_string,
          price: price_string,
          quantity: quantity_string
        })

      assert error_message ==
               "The price given is invalid, it must be positive and have two decimal places."
    end

    test "returns error if quantity_string is invalid" do
      date_string = "2021-01-01"
      transaction_type_string = "buy"
      price_string = "10000.00"
      quantity_string = "1"

      {:error, error_message} =
        Transaction.create_transaction(%{
          date: date_string,
          transaction_type: transaction_type_string,
          price: price_string,
          quantity: quantity_string
        })

      assert error_message ==
               "The quantity is invalid, it must be a positive number with eight decimal places."
    end
  end

  describe "update_transaction" do
    test "works for updating quantity" do
      transaction = build(:transaction)
      new_quantity = Decimal.new("999.00000000")
      update_params = %{quantity: new_quantity}

      {:ok, %Transaction{quantity: quantity}} =
        Transaction.update_transaction(transaction, update_params)

      assert quantity == new_quantity
    end

    test "throws error when updating date" do
      transaction = build(:transaction)
      update_params = %{date: Date.from_iso8601("2022-02-02")}

      {:error, "Cannot update transaction date"} =
        Transaction.update_transaction(transaction, update_params)
    end

    test "throws error when updating transaction_type" do
      transaction = build(:transaction, transaction_type: :sell)
      update_params = %{transaction_type: :buy}

      {:error, "Cannot update transaction transaction type"} =
        Transaction.update_transaction(transaction, update_params)
    end

    test "throws error when updating price" do
      transaction = build(:transaction)
      update_params = %{price: Decimal.new("100.00")}

      {:error, "Cannot update transaction price"} =
        Transaction.update_transaction(transaction, update_params)
    end
  end
end
