defmodule TaxLotAllocator do
  @moduledoc """
  This module is responsible for parsing the stdio and argument inputs, building the transactions
  from the transaction log, and handling the main business logic for processing the transaction
  log given the desired tax lot selection algorithm. 
  """

  alias TaxLotAllocator.Helpers.Parser

  alias TaxLotAllocator.Data.{
    TaxLot,
    Transaction
  }

  alias TaxLotAllocator.Helpers.TaxLotPriorityQueue

  def main(args \\ []) do
    stdio = IO.read(:stdio, :all)

    args
    |> parse_args
    |> Parser.validate_tax_lot_selection_algorithm()
    |> case do
      {:ok, algorithm} ->
        case process_transaction_log(stdio, algorithm) do
          {:error, error} ->
            IO.puts(error)

          output ->
            IO.puts(output)
        end

      {:error, error} ->
        IO.puts(error)
    end
  end

  defp parse_args(args) do
    {options, _, _} = OptionParser.parse(args, strict: [algorithm: :string])

    Keyword.get(options, :algorithm)
  end

  @doc """
  This function is responsible for processing the stdio transaction log, and either
  returning a human readable string of the remaining tax lots, or returning any errors
  that arose while processing the transaction log. 

  The following is a description of the business logic housed in this function:
    1) Initiate the tax lot priority queue with the appropriate algorithm.
    2) Build the transactions from the stdio transaction log
    3) Sort the transactions such that earlier transactions come first, where :buy transactions
       come before :sell transactions for those with the same date.
    4) Iterate through the sorted transactions, while keeping track of:
        - A running list of pending transactions to be inserted into the next tax lot
        - The id to be used in creating the next tax lot
    3) when you reach either a sell transaction or a new date: 
        a) create a tax lot with the transactions
        b) add tax lot to priority queue
    4) For each buy transaction:
        a) Ff it has the same date as the current pending_tax_lot_transactions, add it to this running list
        b) If it has a date later, convert the pending_tax_lot_transactions to a tax lot, add it 
           to the priority queue, and start a new pending_tax_lot_transactions list with the current transaction
    5) When the loop reaches a sell transaction, pop from priority queue and do the following: 
        a) if there are pending tax lot transactions, create a tax lot and add them to the priority queue
        b) if priotity queue is empty, do nothing
        c) if tax lot quantity is greater than the sell transaction's quantity, update tax lot and add back to priority queue
        d) if the tax lot quantity = transaction quantity, return the priority queue without the current tax lto
        e) if sell transaction's quantity > tax lot, update sell transaction quantity and repeat 3
    6) When done iterating though sorted transactions, if there are any remaining transactions in
       the pending_tax_lot_transactions list, create a tax lot and add it to the priority queue. 
    7) Print out any remaining transaction logs.
  """
  @spec process_transaction_log(stdio :: String.t(), algorithm :: :buy | :sell) ::
          String.t() | {:error, String.t()}
  def process_transaction_log(stdio, algorithm) do
    # 1
    priority_queue = TaxLotPriorityQueue.initialize_tax_lot_priority_queue(algorithm)

    # 2
    with {:ok, transactions} <- build_transactions(stdio),
         # 3
         sorted_transactions <- sort_transactions(transactions) do
      # 4 
      # Accumulator: {tax lot priority queue, pending tax lot transactions of the same date, next tax lot id}
      sorted_transactions
      |> Enum.reduce({priority_queue, [], 1}, fn transaction,
                                                 {pq, pending_tax_lot_transactions,
                                                  next_tax_lot_id} ->
        case transaction.transaction_type do
          :buy ->
            # 4
            process_buy_transaction(
              pq,
              pending_tax_lot_transactions,
              transaction,
              next_tax_lot_id
            )

          :sell ->
            # 5
            updated_priority_queue =
              process_sell_transaction(
                pq,
                pending_tax_lot_transactions,
                transaction,
                next_tax_lot_id
              )

            {updated_priority_queue, [], next_tax_lot_id}
        end
      end)
      |> case do
        # 7
        {priority_queue, [], _next_tax_lot_id} ->
          TaxLotPriorityQueue.print_remaining_tax_lots(priority_queue)

        # 6
        {priority_queue, pending_tax_lot_transactions, next_tax_lot_id} ->
          pending_tax_lot_transactions_date = Enum.at(pending_tax_lot_transactions, 0).date

          {:ok, tax_lot} =
            TaxLot.create_tax_lot(
              next_tax_lot_id,
              pending_tax_lot_transactions_date,
              pending_tax_lot_transactions
            )

          updated_priority_queue = PSQ.put(priority_queue, tax_lot)

          # 7
          TaxLotPriorityQueue.print_remaining_tax_lots(updated_priority_queue)
      end
    end
  end

  @spec process_buy_transaction(
          priority_queue :: PSQ.t(),
          pending_tax_lot_transactions :: [Transaciton.t()],
          transaction :: Transaction.t(),
          next_tax_lot_id :: Integer.t()
        ) ::
          {PSQ.t(), [Transaction.t()], Integer.t()}
  def process_buy_transaction(priority_queue, [], %Transaction{} = transaction, next_tax_lot_id) do
    {priority_queue, [transaction], next_tax_lot_id}
  end

  def process_buy_transaction(
        priority_queue,
        pending_tax_lot_transactions,
        %Transaction{date: transaction_date} = transaction,
        next_tax_lot_id
      ) do
    pending_tax_lot_transactions_date = Enum.at(pending_tax_lot_transactions, 0).date

    # 4a
    if Date.compare(pending_tax_lot_transactions_date, transaction_date) == :eq do
      {priority_queue, [transaction | pending_tax_lot_transactions], next_tax_lot_id}

      # 4b
    else
      {:ok, tax_lot} =
        TaxLot.create_tax_lot(
          next_tax_lot_id,
          pending_tax_lot_transactions_date,
          pending_tax_lot_transactions
        )

      updated_priority_queue = PSQ.put(priority_queue, tax_lot)

      {updated_priority_queue, [transaction], next_tax_lot_id + 1}
    end
  end

  @spec process_sell_transaction(
          priority_queue :: PSQ.t(),
          pending_tax_lot_transactions :: [Transaciton.t()],
          transaction :: Transaction.t(),
          next_tax_lot_id :: Integer.t()
        ) ::
          PSQ.t()
  def process_sell_transaction(
        priority_queue,
        pending_tax_lot_transactions,
        %Transaction{quantity: transaction_quantity} = transaction,
        next_tax_lot_id
      ) do
    # 5a
    priority_queue =
      if length(pending_tax_lot_transactions) > 0 do
        pending_tax_lot_transactions_date = Enum.at(pending_tax_lot_transactions, 0).date

        {:ok, tax_lot} =
          TaxLot.create_tax_lot(
            next_tax_lot_id,
            pending_tax_lot_transactions_date,
            pending_tax_lot_transactions
          )

        PSQ.put(priority_queue, tax_lot)
      else
        priority_queue
      end

    case PSQ.pop(priority_queue) do
      # 5b: nil is returned when the priority queue is empty
      {nil, priority_queue} ->
        priority_queue

      {tax_lot, updated_priority_queue} ->
        case Decimal.compare(tax_lot.quantity, transaction_quantity) do
          # 5c: 
          :gt ->
            updated_quantity = Decimal.sub(tax_lot.quantity, transaction_quantity)
            {:ok, updated_tax_lot} = TaxLot.update_tax_lot(tax_lot, %{quantity: updated_quantity})
            updated_priority_queue = PSQ.put(updated_priority_queue, updated_tax_lot)
            updated_priority_queue

          # 5d
          :eq ->
            updated_priority_queue

          # 5e
          :lt ->
            updated_quantity = Decimal.sub(transaction.quantity, tax_lot.quantity)

            {:ok, updated_transaction} =
              Transaction.update_transaction(transaction, %{quantity: updated_quantity})

            process_sell_transaction(
              updated_priority_queue,
              [],
              updated_transaction,
              next_tax_lot_id
            )
        end
    end
  end

  @doc """
  This function is responsible for taking in the transaction log from the stdio, 
  parsing it into transaction creation parameters, and building a list of transactions
  from these parameters.

  In the event that the parameters are invalid, this funciton will return the appropriate
  error.
  """
  @spec build_transactions(stdio :: String.t()) ::
          {:ok, [Transaction.t()]} | {:error, String.t()}
  def build_transactions(stdio) do
    stdio
    |> Parser.parse_transactions_from_input()
    |> Enum.reduce_while({:ok, []}, fn transaction_string, {:ok, transactions} ->
      with {:ok, transaction_params} <- Parser.parse_transaction(transaction_string),
           {:ok, transaction} <- Transaction.create_transaction(transaction_params) do
        {:cont, {:ok, transactions ++ [transaction]}}
      else
        {:error, error_message} ->
          {:halt, {:error, error_message}}
      end
    end)
  end

  @doc """
  This function sorts a list of transaction, first by transaction type where :buy transactions
  come before :sell transactions, then by date, such that the earliest transactions by date
  are ordered first, and for those with the same date, buy transactions come before sell transactions.
  """
  @spec sort_transactions([Transaction.t()]) :: [Transaction.t()]
  def sort_transactions(transactions) do
    transactions
    |> Enum.sort(
      &(Transaction.order_by_transaction_type(&1.transaction_type, &2.transaction_type) != :lt)
    )
    |> Enum.sort(&(Date.compare(&1.date, &2.date) != :gt))
  end
end
