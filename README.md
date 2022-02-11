# OrderBook

An order book implementation.

The order book is a struct, where `:bids` and `:asks` are modeled by `PriceTree`s, which are just AVL trees modified to take a price as a key, and a queue of orders (`OrderQueue`) as a value.

The order book supports limit-orders only at the moment. 

When an order is submitted to the book (via the `price_match/2` function), a time-price match is attempted with orders that are queued up in the system. If there is not enough volume to resolve the submitted order, or if there are no orders at price points that would satisfy the order, then the index of the order is added to an `OrderQueue` at a given `price` in either the `:bids` or `:asks` `PriceTree`. *Note that only the index is added to the queue, given that Erlang `:queue`s don't implement an API for element modifications (or doing so would be highly inefficient)*. Therefore, the queued order `:id` is matched by the actual order information inserted in the `:active_orders` key of the `OrderBook`. 

Fulfillments, order-queuing, etc., all operate on **both** the `OrderQueue` at a particular price-point, and the `:active_orders` map. If an order is absent from the `:active_orders`, then it is also absent from the `OrderQueue` at its price-point, and vice-versa.

TODO: 
- transaction registration
- implement "all-or-none" functionality
- implement market-orders
