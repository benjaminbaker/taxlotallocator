defmodule TaxLotAllocator.Helpers.TaxLotPriorityQueue do
  @moduledoc """
  This module is responsible for initializing the tax lot priority queue,
  based on the algorithm passed into the script: :fifo | :hifo.

  In initializing the priority queue, we are setting the id of the tax lot as
  the key of each item in the queue, and set custom values for means of comparison
  depending on the desired algorithm, :fifo or :hifo.

  For the priority queue, we are using the PSQ library: https://hexdocs.pm/psq/0.1.0/PSQ.html
    - Fetching the minimum element occurs in O(1) time.
    - Put and pop operations occur in O(log n) time.
    - Creating a PSQ from a list occurs in O(n log n) time.
  """

  alias TaxLotAllocator.Data.TaxLot

  @doc """
  To initialize the tax lot priority queue to sort by earliest tax lot (fifo),
  we pass in a custom comparison value function to convert the date of the tax 
  lot to unix time, so that the earliest dates are returned first.
  """
  @spec print_remaining_tax_lots(algorithm :: :fifo | :hifo) ::
          PSQ.t()
  def initialize_tax_lot_priority_queue(:fifo) do
    PSQ.new(
      &(&1.date
        |> Date.to_iso8601()
        |> (fn t -> t <> "T00:00:00Z" end).()
        |> DateTime.from_iso8601()
        |> elem(1)
        |> DateTime.to_unix()),
      & &1.id
    )
  end

  @doc """
  To initialize the tax lot priority queue to sort by highest price first (hifo),
  we pass in a custom comparison value function to convert the price to a negative 
  float, so that the highest decimal price will be returned first.
  """
  def initialize_tax_lot_priority_queue(:hifo) do
    PSQ.new(&(&1.price |> Decimal.to_float() |> (fn price -> price * -1 end).()), & &1.id)
  end

  @doc """
  This function iterates through the priority queue, composing the remaining tax lots 
  into a human readable string that can be returned to the console.
  """
  @spec print_remaining_tax_lots(priority_queue :: PSQ.t()) ::
          String.t()
  def print_remaining_tax_lots(priority_queue) do
    case PSQ.pop(priority_queue) do
      {nil, _priority_queue} ->
        "There are no remaining tax lots in the queue."

      {tax_lot, updated_priority_queue} ->
        tax_lot_string = TaxLot.convert_tax_lot_to_string(tax_lot)
        do_print_remaining_tax_lots(updated_priority_queue, tax_lot_string)
    end
  end

  defp do_print_remaining_tax_lots(priority_queue, accumulator) do
    case PSQ.pop(priority_queue) do
      {nil, _priority_queue} ->
        accumulator

      {tax_lot, priority_queue} ->
        tax_lot_string = TaxLot.convert_tax_lot_to_string(tax_lot)
        updated_accumulator = accumulator <> "\n" <> tax_lot_string
        do_print_remaining_tax_lots(priority_queue, updated_accumulator)
    end
  end
end
