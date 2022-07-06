# TaxLotAllocator

**How to run**

Install elixir on your machine if you do not already have it, you can follow instructions [here](https://elixir-lang.org/install.html)

Get a local copy of the TaxLotAllocator repo

Run `mix deps.get` from the main directory

Run `mix compile`

Run `mix escript.build`

Now the script is ready to run, pass in the algorithm with the `--algorithm` option

Examples:
```
echo -e '2021-01-01,buy,10000.00,1.00000000\n2021-02-01,sell,20000.00,0.50000 000' | ./tasklotallocator --algorithm fifo

echo -e '2021-01-01,buy,10000.00,1.00000000\n2021-01-02,buy,20000.00,1.000000 00\n2021-02-01,sell,20000.00,1.50000000' | ./tasklotallocator --algorithm fifo

echo -e '2021-01-01,buy,10000.00,1.00000000\n2021-01-02,buy,20000.00,1.000000 00\n2021-02-01,sell,20000.00,1.50000000' | ./tasklotallocator --algorithm hifo
```

Assumptions made:
* When computing the weighted average for task lots, fractional cents are rounded using Half-Even rounding.
* Price and quantity values of 0 are considered invalid.
* The input format given in the prompt is the only acceptable format. The script will strip spaces from the ends of transaction field inputs and newline characters from the end of the stdio input.
* If the quantity of sell transactions is than the quantity of the buy tax lots, the system will simply return that all tax lots have been sold.
* The transactions are assumed to be ordered by date, but with buy/sell transactions randomly sorted per date.


Future improvements ideas:
* I do not like how the `id` of the tax lots is kept track in memory within the process_transaction_log() function. If built in a prodution environment, I would create a dedicated table or service to track monotonically increasing ids used for creating tax lots.
* I do not like the custom comparison fields needed when initializing the priority queue to properly sort tax lots, as the code is non-intuitive. I would dedicate time to finding a better priority queue library that can accept custom comparitor functions instead.
* I would make the error messages "richer" so that they return the invalid input/value, so it is more clear to the user what was incorrect about their inputs to the script.
* In creating the tax lots, I would have a has_many relationship with transactions (provided we have a DB and Ecto wrapping it) so that it is clear which transactions map to each tax lot.
