defmodule OrderBook do
  @moduledoc """
  :bids -> %PriceTree{}
  %PriceTree{} -> %OrderQueue{}'s
  """
  alias OrderBook.{PriceTree, OrderQueue}

  defstruct [
    :name,
    :currency,
    :sym,

    :participants,

    :asks,
    :bids,
    :active_orders,
    :last_order_id,

    :completed_transactions,
    :last_transaction_id,

    :total_volume_traded,
    :total_volume_pending,
  ]

  def new do
    %{ %__MODULE__{} | 
      name: "Default Exchange",
      currency: :clp,
      sym: :default_exchange,
      participants: %{},
      asks: PriceTree.new(),
      bids: PriceTree.new(),
      active_orders: %{},
      last_order_id: 0,
      completed_transactions: %{},
      last_transaction_id: 0,
      total_volume_traded: 0,
      total_volume_pending: 0
    }
  end

  defmodule Order do
    defstruct [
      {:id, nil},
      {:trader_id, nil},
      {:side, nil}, # one of: [:ask, :bid]
      {:price, 0},
      {:qty, 0},
      {:created_at, DateTime.now("Etc/UTC")},
      {:modified_at, DateTime.now("Etc/UTC")}
    ]
  end

  defmodule Transaction do
    defstruct [
      {:id, nil},
      {:bid_order, nil},
      {:ask_order, nil},
      {:type, nil}, # :partial, :full
      {:acknowledged_at, DateTime.now("Etc/UTC")}
    ]
  end

  defmodule Trader do
    defstruct [
      {:id, nil},
      {:active_orders, %{}},
      {:transactions, %{}}
    ]
  end

  @doc """
  Returns a new order id, simultaneously increasing last_order_id.
  """
  def get_order_id(%__MODULE__{} = book) do
    new_book = Map.update!(book, :last_order_id, &(&1 + 1))    
    { new_book.last_order_id, new_book }
  end

  def get_transaction_id(%__MODULE__{} = book) do
    new_book = Map.update!(book, :last_transaction_id, &(&1 + 1))    
    { new_book.last_transaction_id, new_book }
  end

  def get_active_order!(%__MODULE__{} = book, id) when is_number(id) do
    Map.fetch!(book.active_orders, id)
  end

  def get_active_order(%__MODULE__{} = book, id) when is_number(id) do
    Map.get(book.active_orders, id, nil)
  end

  def insert_active_order(%__MODULE__{} = book, %Order{id: id} = order) when not is_nil(id) do
    put_in(book, [Access.key(:active_orders, %{}), Access.key(id, 0)], order)
  end

  def remove_active_order(%__MODULE__{} = book, %Order{id: id}) when not is_nil(id) do
    pop_in(book, [Access.key(:active_orders, %{}), Access.key(id, 0)]) |> elem(1)
  end

  def update_active_order(%__MODULE__{} = book, %Order{id: id}, field, func) when not is_nil(id) and is_atom(field) do
    order = Map.fetch!(book.active_orders, id) # fetch updated order
    put_in(book, [Access.key(:active_orders, %{}), Access.key(id, 0)], Map.update!(order, field, func))
  end

  def enqueue_active_order(%__MODULE__{} = book, %Order{id: id}) when not is_nil(id) do 
    with order = %Order{price: price} <- get_active_order(book, id) do # check it actually is registered

      price_tree_key = bids_or_asks(order)
      update_in(book, [Access.key(price_tree_key, %PriceTree{})], fn price_tree ->
        if PriceTree.has_price?(price_tree, price) do
          order_queue = price_tree
                            |> PriceTree.get_order_queue(price)
                            |> OrderQueue.push(id)

          PriceTree.put_order_queue(price_tree, price, order_queue)
        else
          new_order_queue = %OrderQueue{} 
                            |> OrderQueue.push(id)
          PriceTree.put_order_queue(price_tree, price, new_order_queue)
        end
      end)
    end
  end

  def advance_queue(%__MODULE__{} = book, side, price) when is_atom(side) and is_number(price) do
    update_in(book, [Access.key(side, %PriceTree{})], fn price_tree ->
      queue = PriceTree.get_order_queue(price_tree, price)
      cond do
        OrderQueue.is_empty?(queue) -> 
          PriceTree.remove_price(price_tree, price)
        true ->
          price_tree = PriceTree.update_order_queue(price_tree, price, &(OrderQueue.advance(&1)))
          # Check if upon advancing queue our queue is empty. If so, remove the price level. TODO: refactor
          case OrderQueue.is_empty?(PriceTree.get_order_queue(price_tree, price)) do
            true -> PriceTree.remove_price(price_tree, price)
            false -> price_tree
          end
      end
    end)
  end

  def price_match({%__MODULE__{} = book, %Order{side: :bid, qty: 0}}), do: book
  def price_match({%__MODULE__{} = book, %Order{} = order}), do: price_match(book, order)
  def price_match(%__MODULE__{} = book, %Order{id: id, side: :bid} = bid_order) when is_number(id) do
    lowest_asking_price = PriceTree.lowest_price(book.asks)

    cond do
      lowest_asking_price > bid_order.price -> 
        book
        |> insert_active_order(bid_order)
        |> enqueue_active_order(bid_order)
      lowest_asking_price <= bid_order.price ->
        book
        |> execute_order(bid_order, lowest_asking_price)
        |> price_match()
    end
  end

  def execute_order(%__MODULE__{} = book, %Order{side: side} = live_order, price_point) do
    price_tree_key = case side do
      :ask -> :bids
      :bid -> :asks
    end

    if not PriceTree.has_price?(Map.get(book, price_tree_key), price_point) do
      raise ArgumentError, "price_point [#{price_point}] provided to execute_order/3 doesn't exist in price tree [#{price_tree_key}] of book [#{book.name}]"
    end

    order_queue = PriceTree.get_order_queue(Map.get(book, price_tree_key), price_point)
    first_order = OrderBook.get_active_order(book, OrderQueue.peek(order_queue))

    cond do
      first_order.qty > live_order.qty ->
        book
        |> update_active_order(first_order, :qty, &(&1 - live_order.qty))
        |> register_transaction(live_order, first_order)
        |> (&({&1, %{ live_order | qty: 0 }})).()
      first_order.qty <= live_order.qty ->
        book
        |> remove_active_order(first_order)
        |> advance_queue(price_tree_key, price_point)
        |> register_transaction(live_order, first_order)
        |> (&({&1, %{ live_order | qty: live_order.qty - first_order.qty}})).()
    end
  end

  def register_transaction(%__MODULE__{} = book, %Order{} = _order_a, %Order{} = _order_b) do
    book
  end

  defp bids_or_asks(%Order{side: :bid}), do: :bids
  defp bids_or_asks(%Order{side: :ask}), do: :asks

    # Reduce the number of outstanding ask_amt
    # Reduce the number of outstanding bid_amt
    # Reduce the total ask size
    # Reduce the total bid size
    # Increase the total volume traded
    # Reduce the total volume pending (2 * traded)

end
