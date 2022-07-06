defmodule TaxLotAllocator.Helpers.TaxLotPriorityQueueTest do
  use ExUnit.Case
  doctest TaxLotAllocator.Helpers.TaxLotPriorityQueue

  import TaxLotAllocator.Factory

  alias TaxLotAllocator.Helpers.TaxLotPriorityQueue
  alias TaxLotAllocator.Data.TaxLot

  describe "initialize_tax_lot_priority_queue" do
    test "orders tax lots by date when given fifo" do
      {:ok, date_1} = Date.from_iso8601("2022-01-01")
      {:ok, date_2} = Date.from_iso8601("2021-01-01")
      {:ok, date_3} = Date.from_iso8601("2021-02-01")

      tax_lot_1 = build(:tax_lot, id: 1, date: date_1)
      tax_lot_2 = build(:tax_lot, id: 2, date: date_2)
      tax_lot_3 = build(:tax_lot, id: 3, date: date_3)

      priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:fifo)

      priority_queue =
        priority_queue
        |> PSQ.put(tax_lot_1)
        |> PSQ.put(tax_lot_2)
        |> PSQ.put(tax_lot_3)

      {expected_tax_lot, updated_priority_queue} = PSQ.pop(priority_queue)
      assert expected_tax_lot.id == 2

      {expected_tax_lot, updated_priority_queue} = PSQ.pop(updated_priority_queue)
      assert expected_tax_lot.id == 3

      {expected_tax_lot, _updated_priority_queue} = PSQ.pop(updated_priority_queue)
      assert expected_tax_lot.id == 1
    end

    test "orders tax lots by price when given hifo" do
      tax_lot_1 = build(:tax_lot, id: 1, price: Decimal.new("10.00"))
      tax_lot_2 = build(:tax_lot, id: 2, price: Decimal.new("1000.00"))
      tax_lot_3 = build(:tax_lot, id: 3, price: Decimal.new("1.00"))

      priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:hifo)

      priority_queue =
        priority_queue
        |> PSQ.put(tax_lot_1)
        |> PSQ.put(tax_lot_2)
        |> PSQ.put(tax_lot_3)

      {expected_tax_lot, updated_priority_queue} = PSQ.pop(priority_queue)
      assert expected_tax_lot.id == 2

      {expected_tax_lot, updated_priority_queue} = PSQ.pop(updated_priority_queue)
      assert expected_tax_lot.id == 1

      {expected_tax_lot, _updated_priority_queue} = PSQ.pop(updated_priority_queue)
      assert expected_tax_lot.id == 3
    end
  end

  describe "print_remaining_tax_lots" do
    test "works when the priority queue is empty" do
      priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:hifo)

      assert "There are no remaining tax lots in the queue." ==
               TaxLotPriorityQueue.print_remaining_tax_lots(priority_queue)
    end

    test "works when priority queue has one tax lot" do
      empty_priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:fifo)

      tax_lot = build(:tax_lot)
      priority_queue = PSQ.put(empty_priority_queue, tax_lot)

      assert TaxLot.convert_tax_lot_to_string(tax_lot) ==
               TaxLotPriorityQueue.print_remaining_tax_lots(priority_queue)
    end

    test "works when priority queue has multiple tax lots" do
      empty_priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(:hifo)

      tax_lot_1 = build(:tax_lot, id: 1)
      tax_lot_2 = build(:tax_lot, id: 2)

      priority_queue =
        empty_priority_queue
        |> PSQ.put(tax_lot_1)
        |> PSQ.put(tax_lot_2)

      tax_lot_1_string = TaxLot.convert_tax_lot_to_string(tax_lot_1)
      tax_lot_2_string = TaxLot.convert_tax_lot_to_string(tax_lot_2)

      expected_string_output = tax_lot_1_string <> "\n" <> tax_lot_2_string

      assert expected_string_output ==
               TaxLotPriorityQueue.print_remaining_tax_lots(priority_queue)
    end
  end
end
