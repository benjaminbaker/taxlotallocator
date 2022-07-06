defmodule TaxLotAllocatorTest do
  use ExUnit.Case
  doctest TaxLotAllocator

  import TaxLotAllocator.Factory

  alias TaxLotAllocator.Data.{
    TaxLot,
    Transaction
  }

  alias TaxLotAllocator.Helpers.TaxLotPriorityQueue

  describe "build_transactions" do
    test "works with buy and sell transactions" do
      stdin = "2021-01-01,buy,10000.00,1.00000000\n2021-02-01,sell,20000.00,0.50000000"
      {:ok, transactions} = TaxLotAllocator.build_transactions(stdin)

      {:ok, buy_date} = Date.from_iso8601("2021-01-01")

      expected_buy_transaction =
        build(:transaction,
          date: buy_date,
          transaction_type: :buy,
          price: Decimal.new("10000.00"),
          quantity: Decimal.new("1.00000000")
        )

      {:ok, sell_date} = Date.from_iso8601("2021-02-01")

      expected_sell_transaction =
        build(:transaction,
          date: sell_date,
          transaction_type: :sell,
          price: Decimal.new("20000.00"),
          quantity: Decimal.new("0.50000000")
        )

      assert transactions == [expected_buy_transaction, expected_sell_transaction]
    end

    test "works with just buy transactions" do
      stdin =
        "2021-01-01,buy,10000.00,1.00000000\n2021-01-02,buy,20000.00,2.00000000\n2021-01-03,buy,30000.00,3.00000000"

      {:ok, transactions} = TaxLotAllocator.build_transactions(stdin)

      {:ok, buy_date_1} = Date.from_iso8601("2021-01-01")
      {:ok, buy_date_2} = Date.from_iso8601("2021-01-02")
      {:ok, buy_date_3} = Date.from_iso8601("2021-01-03")

      expected_buy_transaction_1 =
        build(:transaction,
          date: buy_date_1,
          transaction_type: :buy,
          price: Decimal.new("10000.00"),
          quantity: Decimal.new("1.00000000")
        )

      expected_buy_transaction_2 =
        build(:transaction,
          date: buy_date_2,
          transaction_type: :buy,
          price: Decimal.new("20000.00"),
          quantity: Decimal.new("2.00000000")
        )

      expected_buy_transaction_3 =
        build(:transaction,
          date: buy_date_3,
          transaction_type: :buy,
          price: Decimal.new("30000.00"),
          quantity: Decimal.new("3.00000000")
        )

      assert transactions == [
               expected_buy_transaction_1,
               expected_buy_transaction_2,
               expected_buy_transaction_3
             ]
    end

    test "works with just sell transactions" do
      stdin =
        "2021-01-01,sell,10000.00,1.00000000\n2021-01-02,sell,20000.00,2.00000000\n2021-01-03,sell,30000.00,3.00000000"

      {:ok, transactions} = TaxLotAllocator.build_transactions(stdin)

      {:ok, sell_date_1} = Date.from_iso8601("2021-01-01")
      {:ok, sell_date_2} = Date.from_iso8601("2021-01-02")
      {:ok, sell_date_3} = Date.from_iso8601("2021-01-03")

      expected_sell_transaction_1 =
        build(:transaction,
          date: sell_date_1,
          transaction_type: :sell,
          price: Decimal.new("10000.00"),
          quantity: Decimal.new("1.00000000")
        )

      expected_sell_transaction_2 =
        build(:transaction,
          date: sell_date_2,
          transaction_type: :sell,
          price: Decimal.new("20000.00"),
          quantity: Decimal.new("2.00000000")
        )

      expected_sell_transaction_3 =
        build(:transaction,
          date: sell_date_3,
          transaction_type: :sell,
          price: Decimal.new("30000.00"),
          quantity: Decimal.new("3.00000000")
        )

      assert transactions == [
               expected_sell_transaction_1,
               expected_sell_transaction_2,
               expected_sell_transaction_3
             ]
    end

    test "works with no transactions" do
      stdin = ""
      {:ok, transactions} = TaxLotAllocator.build_transactions(stdin)

      assert transactions == []
    end

    test "properly returns validation error" do
      stdin = "2021-01-33,buy,10000.00,1.00000000\n2021-02-01,sell,20000.00,0.50000000"

      {:error, "The date provided is not an actual date."} =
        TaxLotAllocator.build_transactions(stdin)
    end
  end

  describe "sort_transactions" do
    test "sorts by date, with buy transactions coming before sell transaction" do
      {:ok, date_1} = Date.from_iso8601("2022-01-01")
      transaction_1 = build(:transaction, date: date_1, transaction_type: :buy)
      transaction_2 = build(:transaction, date: date_1, transaction_type: :sell)
      transaction_3 = build(:transaction, date: date_1, transaction_type: :buy)

      {:ok, date_2} = Date.from_iso8601("2021-01-01")
      transaction_4 = build(:transaction, date: date_2, transaction_type: :sell)
      transaction_5 = build(:transaction, date: date_2, transaction_type: :sell)
      transaction_6 = build(:transaction, date: date_2, transaction_type: :buy)

      {:ok, date_3} = Date.from_iso8601("2021-02-01")
      transaction_7 = build(:transaction, date: date_3, transaction_type: :buy)

      transactions = [
        transaction_1,
        transaction_2,
        transaction_3,
        transaction_4,
        transaction_5,
        transaction_6,
        transaction_7
      ]

      [
        %Transaction{date: ^date_2, transaction_type: :buy},
        %Transaction{date: ^date_2, transaction_type: :sell},
        %Transaction{date: ^date_2, transaction_type: :sell},
        %Transaction{date: ^date_3, transaction_type: :buy},
        %Transaction{date: ^date_1, transaction_type: :buy},
        %Transaction{date: ^date_1, transaction_type: :buy},
        %Transaction{date: ^date_1, transaction_type: :sell}
      ] = TaxLotAllocator.sort_transactions(transactions)
    end
  end

  # NOTE: update to use tax lot factory methods
  describe "process_buy_transaction" do
    test "works for empty list of buy transactions" do
      priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:fifo)
      transaction = build(:transaction)

      {^priority_queue, [^transaction], 1} =
        TaxLotAllocator.process_buy_transaction(priority_queue, [], transaction, 1)
    end

    test "works when the transaction has the same date as the buy transactions" do
      priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:fifo)
      transaction_1 = build(:transaction, price: Decimal.new("1.00"))
      transaction_2 = build(:transaction, price: Decimal.new("2.00"))
      buy_transactions = [transaction_1, transaction_2]

      new_transaction = build(:transaction, price: Decimal.new("3.00"))

      {^priority_queue, [^new_transaction, ^transaction_1, ^transaction_2], 1} =
        TaxLotAllocator.process_buy_transaction(
          priority_queue,
          buy_transactions,
          new_transaction,
          1
        )
    end

    test "works when the transaction occured after the current buy transactions" do
      priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:fifo)
      {:ok, date_1} = Date.from_iso8601("2021-01-01")
      {:ok, date_2} = Date.from_iso8601("2021-01-02")

      transaction_1 = build(:transaction, price: Decimal.new("1.00"), date: date_1)
      transaction_2 = build(:transaction, price: Decimal.new("2.00"), date: date_1)
      buy_transactions = [transaction_1, transaction_2]

      new_transaction = build(:transaction, price: Decimal.new("3.00"), date: date_2)

      {priority_queue, [^new_transaction], 2} =
        TaxLotAllocator.process_buy_transaction(
          priority_queue,
          buy_transactions,
          new_transaction,
          1
        )

      {tax_lot, _pq} = PSQ.pop(priority_queue)
      assert {:ok, tax_lot} == TaxLot.create_tax_lot(1, date_1, buy_transactions)
    end
  end

  describe "process_sell_transaction" do
    test "returns priority queue when it is empty" do
      priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:fifo)
      transaction = build(:transaction, transaction_type: :sell)

      assert priority_queue ==
               TaxLotAllocator.process_sell_transaction(priority_queue, [], transaction, 1)
    end

    test "works when the top tax lot has a greater quantity than the sell transaction" do
      empty_priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:fifo)
      buy_quantity = Decimal.new("5.00000000")
      buy_transaction = build(:transaction, transaction_type: :buy, quantity: buy_quantity)

      {:ok, tax_lot} = TaxLot.create_tax_lot(1, buy_transaction.date, [buy_transaction])
      updated_priority_queue = PSQ.put(empty_priority_queue, tax_lot)

      sell_quantity = Decimal.new("2.00000000")
      sell_transaction = build(:transaction, transaction_type: :sell, quantity: sell_quantity)

      returned_priority_queue =
        TaxLotAllocator.process_sell_transaction(updated_priority_queue, [], sell_transaction, 1)

      quantity_difference = Decimal.sub(buy_quantity, sell_quantity)

      {%TaxLot{quantity: ^quantity_difference}, _priority_queue} =
        PSQ.pop(returned_priority_queue)
    end

    test "works when the top tax lot has an equal quantity than the sell transaction" do
      empty_priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:fifo)
      buy_transaction = build(:transaction, transaction_type: :buy)

      {:ok, tax_lot} = TaxLot.create_tax_lot(1, buy_transaction.date, [buy_transaction])
      updated_priority_queue = PSQ.put(empty_priority_queue, tax_lot)

      sell_transaction = build(:transaction, transaction_type: :sell)

      returned_priority_queue =
        TaxLotAllocator.process_sell_transaction(updated_priority_queue, [], sell_transaction, 1)

      # In the event the returned tax lot has the same quantity as the sell transaction, simply pop
      # it from the priority queue and return the updated priority queue. In this case, because there
      # was only one tax lot in the priority queue, return an empty priority queue
      {nil, _priority_queue} = PSQ.pop(returned_priority_queue)
    end

    test "works when the top tax lot has a smaller quantity than the sell transaction" do
      empty_priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:fifo)

      buy_transaction_1 =
        build(:transaction, transaction_type: :buy, quantity: Decimal.new("1.00000000"))

      buy_transaction_2 =
        build(:transaction, transaction_type: :buy, quantity: Decimal.new("2.00000000"))

      buy_transaction_3 =
        build(:transaction, transaction_type: :buy, quantity: Decimal.new("3.00000000"))

      {:ok, tax_lot_1} = TaxLot.create_tax_lot(1, buy_transaction_1.date, [buy_transaction_1])
      {:ok, tax_lot_2} = TaxLot.create_tax_lot(1, buy_transaction_2.date, [buy_transaction_2])
      {:ok, tax_lot_3} = TaxLot.create_tax_lot(1, buy_transaction_3.date, [buy_transaction_3])

      updated_priority_queue =
        empty_priority_queue
        |> PSQ.put(tax_lot_1)
        |> PSQ.put(tax_lot_2)
        |> PSQ.put(tax_lot_3)

      sell_transaction =
        build(:transaction, transaction_type: :sell, quantity: Decimal.new("6.00000000"))

      returned_priority_queue =
        TaxLotAllocator.process_sell_transaction(updated_priority_queue, [], sell_transaction, 1)

      # Because the quantity of the sell transaction equals the sum of the quantities of the three tax lots
      # when this is done processing the sell transaction, the priority queue should be empty
      {nil, _priority_queue} = PSQ.pop(returned_priority_queue)
    end

    test "works when there pending_tax_lot_transactions when processing a sell transaction" do
      empty_priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:fifo)
      buy_quantity = Decimal.new("5.00000000")
      buy_transaction = build(:transaction, transaction_type: :buy, quantity: buy_quantity)

      sell_quantity = Decimal.new("2.00000000")
      sell_transaction = build(:transaction, transaction_type: :sell, quantity: sell_quantity)

      returned_priority_queue =
        TaxLotAllocator.process_sell_transaction(
          empty_priority_queue,
          [buy_transaction],
          sell_transaction,
          1
        )

      quantity_difference = Decimal.sub(buy_quantity, sell_quantity)

      {%TaxLot{quantity: ^quantity_difference}, _priority_queue} =
        PSQ.pop(returned_priority_queue)
    end
  end

  describe "process_transaction_log" do
    test "example 1" do
      stdio = "2021-01-01,buy,10000.00,1.00000000\n2021-02-01,sell,20000.00,0.50000000"
      algorithm = :fifo

      assert "1,2021-01-01,10000.00,0.50000000" == TaxLotAllocator.process_transaction_log(stdio, algorithm)
    end

    test "example 2" do
      stdio =
        "2021-01-01,buy,10000.00,1.00000000\n2021-01-02,buy,20000.00,1.00000000\n2021-02-01,sell,20000.00,1.50000000"

      algorithm = :fifo

      assert "2,2021-01-02,20000.00,0.50000000" ==
               TaxLotAllocator.process_transaction_log(stdio, algorithm)
    end

    test "example 3" do
      stdio =
        "2021-01-01,buy,10000.00,1.00000000\n2021-01-02,buy,20000.00,1.00000000\n2021-02-01,sell,20000.00,1.50000000"

      algorithm = :hifo

      assert "1,2021-01-01,10000.00,0.50000000" ==
               TaxLotAllocator.process_transaction_log(stdio, algorithm)
    end

    test "only sell transactions" do
      stdio = "2021-02-01,sell,20000.00,1.50000000"

      algorithm = :hifo

      assert "There are no remaining tax lots in the queue." ==
               TaxLotAllocator.process_transaction_log(stdio, algorithm)
    end

    test "sell transaction is interspersed with buy transactions of the same date" do
      stdio =
        "2021-01-01,buy,10000.00,1.00000000\n2021-02-01,sell,20000.00,0.50000000\n2021-01-01,buy,20000.00,2.00000000"

      algorithm = :fifo

      # 16666.67 is the weighted average of the two buy transactions above
      assert "1,2021-01-01,16666.67,2.50000000" ==
               TaxLotAllocator.process_transaction_log(stdio, algorithm)
    end

    test "multiple tax lots before a sell transaction with hifo" do
      stdio =
        "2021-01-01,buy,20000.00,1.00000000\n2021-01-02,buy,30000.00,1.00000000\n2021-01-03,buy,10000.00,1.00000000\n2021-02-01,sell,20000.00,2.00000000"

      algorithm = :hifo

      assert "3,2021-01-03,10000.00,1.00000000" ==
               TaxLotAllocator.process_transaction_log(stdio, algorithm)
    end

    test "multiple tax lots before a sell transaction with fifo" do
      stdio =
        "2021-01-01,buy,10000.00,1.00000000\n2021-01-02,buy,20000.00,1.00000000\n2021-01-03,buy,30000.00,1.00000000\n2021-02-01,sell,20000.00,2.00000000"

      algorithm = :fifo

      assert "3,2021-01-03,30000.00,1.00000000" ==
               TaxLotAllocator.process_transaction_log(stdio, algorithm)
    end

    test "do not process a transactions after the sell transaction's date" do
      stdio = "2021-01-01,sell,20000.00,2.00000000\n2021-01-02,buy,20000.00,1.00000000"
      algorithm = :fifo

      assert "1,2021-01-02,20000.00,1.00000000" ==
               TaxLotAllocator.process_transaction_log(stdio, algorithm)
    end

    test "computes appropriate weighted average" do
      stdio =
        "2021-01-01,buy,20000.00,3.00000000\n2021-01-01,buy,30000.00,7.00000000\n2021-01-01,buy,10000.00,5.00000000\n2021-02-01,sell,20000.00,2.00000000"

      algorithm = :fifo

      assert "1,2021-01-01,21333.33,13.00000000" ==
               TaxLotAllocator.process_transaction_log(stdio, algorithm)
    end

    test "multiple task lots remaining" do
      stdio =
        "2021-01-01,buy,20000.00,1.00000000\n2021-01-02,buy,30000.00,1.00000000\n2021-01-03,buy,20000.00,1.00000000\n2021-02-01,sell,20000.00,1.00000000"

      algorithm = :hifo

      assert "1,2021-01-01,20000.00,1.00000000\n3,2021-01-03,20000.00,1.00000000" ==
               TaxLotAllocator.process_transaction_log(stdio, algorithm)
    end
    
    test "returns error for invalid transaction date" do
      stdio = "2021-01-33,buy,10000.00,1.00000000\n2021-02-01,sell,20000.00,0.50000000"
      algorithm = :fifo

      assert {:error, "The date provided is not an actual date."} == TaxLotAllocator.process_transaction_log(stdio, algorithm)
    end

    test "returns error for invalid transaction input" do
      stdio = "2021-01-01,buy,10000.00\n2021-02-01,sell,20000.00,0.50000000"
      algorithm = :fifo

      assert {:error, "There are an invalid number of fields supplied to create a transaction."} == TaxLotAllocator.process_transaction_log(stdio, algorithm)
    end
  end
end
