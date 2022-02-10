defmodule OrderBookTest do
  use ExUnit.Case
  doctest OrderBook
  alias OrderBook.{Order, PriceTree, OrderQueue}

  test "get_order_id/1 returns a new order id, increments last_order_id" do
    ob = OrderBook.new()
    assert ob.last_order_id == 0
    assert {1, %OrderBook{last_order_id: 1}} = OrderBook.get_order_id(ob)
  end

  test "get_transaction_id/1 returns a new transaction id, increments last_transaction_id" do
    ob = OrderBook.new()
    assert ob.last_transaction_id == 0
    assert {1, %OrderBook{last_transaction_id: 1}} = OrderBook.get_transaction_id(ob)
  end

  test "OrderBook.new() bids and asks start out as empty AVL trees" do
    ob = OrderBook.new()
    assert PriceTree.is_empty?(ob.asks)
    assert PriceTree.is_empty?(ob.bids)
  end

  test "insert_active_order/2 adds an order to the book's active_orders" do
    ob = OrderBook.new()
    order_1 = %Order{id: 1}
    order_2 = %Order{id: 2}

    ob = ob
         |> OrderBook.insert_active_order(order_1)
         |> OrderBook.insert_active_order(order_2)

    assert Map.has_key?(ob.active_orders, order_1.id)
    assert Map.has_key?(ob.active_orders, order_2.id)
  end

  test "get_active_order/2 returns an active order" do
    ob = OrderBook.new()
    order_1 = %Order{id: 1}
    order_2 = %Order{id: 2}

    ob = ob
         |> OrderBook.insert_active_order(order_1)
         |> OrderBook.insert_active_order(order_2)

    assert OrderBook.get_active_order(ob, 1) == order_1
    assert OrderBook.get_active_order(ob, 2) == order_2
  end

  test "remove_active_order/2 removes an order from the book's active_orders" do
    ob = OrderBook.new()
    order_1 = %Order{id: 1}
    order_2 = %Order{id: 2}

    ob = ob
         |> OrderBook.insert_active_order(order_1)
         |> OrderBook.insert_active_order(order_2)
         |> OrderBook.remove_active_order(order_1)

    refute Map.has_key?(ob.active_orders, order_1.id)
    assert Map.has_key?(ob.active_orders, order_2.id)
  end

  test "remove_active_order/2 returns an unmodified book if no order is found to remove" do
    ob = OrderBook.new()
    order_1 = %Order{id: 1}
    fake_order = %Order{id: 2}

    ob = ob
         |> OrderBook.insert_active_order(order_1)
         |> OrderBook.remove_active_order(fake_order)

    assert Map.has_key?(ob.active_orders, order_1.id)
  end

  test "update_active_order/4 updates an order in a book's active_orders" do
    ob = OrderBook.new()
    order_1 = %Order{id: 1}

    ob = 
      ob
      |> OrderBook.insert_active_order(order_1)
      |> OrderBook.update_active_order(order_1, :qty, fn _ -> 500 end)
      |> OrderBook.update_active_order(order_1, :price, &(&1 + 1500))

    updated_order = OrderBook.get_active_order(ob, 1)
    assert updated_order.qty == 500
    assert updated_order.price == 1500
  end

  test "enqueue_active_order/2 correctly enqueues a bid order id at a price level" do
    ob = OrderBook.new()
    order_1 = %Order{id: 1, side: :bid, price: 500, qty: 10}

    ob =
      ob
      |> OrderBook.insert_active_order(order_1)
      |> OrderBook.enqueue_active_order(order_1)


    assert PriceTree.has_price?(ob.bids, order_1.price)
    assert %OrderQueue{} = PriceTree.get_order_queue(ob.bids, order_1.price)
    assert OrderQueue.peek(PriceTree.get_order_queue(ob.bids, order_1.price)) == 1
  end

  test "enqueue_active_order/2 correctly enqueues an ask order id at a price level" do
    ob = OrderBook.new()
    order_1 = %Order{id: 1, side: :ask, price: 500, qty: 10}

    ob =
      ob
      |> OrderBook.insert_active_order(order_1)
      |> OrderBook.enqueue_active_order(order_1)


    assert PriceTree.has_price?(ob.asks, order_1.price)
    assert %OrderQueue{} = PriceTree.get_order_queue(ob.asks, order_1.price)
    assert OrderQueue.peek(PriceTree.get_order_queue(ob.asks, order_1.price)) == 1
  end

  test "advance_queue/3 correctly advances an OrderQueue" do
    order_1 = %Order{id: 1, side: :ask, price: 500, qty: 100}
    order_2 = %Order{id: 2, side: :ask, price: 500, qty: 150}

    book = 
      OrderBook.new()
      |> OrderBook.insert_active_order(order_1)
      |> OrderBook.enqueue_active_order(order_1)
      |> OrderBook.insert_active_order(order_2)
      |> OrderBook.enqueue_active_order(order_2)
      |> OrderBook.advance_queue(:asks, 500)

    order_queue = PriceTree.get_order_queue(book.asks, 500)

    assert OrderQueue.peek(order_queue) == 2
    assert OrderQueue.count(order_queue) == 1
  end

  test "advance_queue/3 closes a price level on an empty OrderQueue" do
    order_1 = %Order{id: 1, side: :ask, price: 500, qty: 100}

    book = 
      OrderBook.new()
      |> OrderBook.insert_active_order(order_1)
      |> OrderBook.enqueue_active_order(order_1)
      |> OrderBook.advance_queue(:asks, 500)

    refute PriceTree.has_price?(book.asks, 500)
  end

  describe "execute_order/3 for :bid order" do
    setup do
      order_1 = %Order{id: 1, side: :ask, price: 500, qty: 100}
      order_2 = %Order{id: 2, side: :ask, price: 500, qty: 150}
      order_3 = %Order{id: 3, side: :ask, price: 150, qty: 300}

      book = 
        OrderBook.new()
        |> OrderBook.insert_active_order(order_1)
        |> OrderBook.enqueue_active_order(order_1)
        |> OrderBook.insert_active_order(order_2)
        |> OrderBook.enqueue_active_order(order_2)
        |> OrderBook.insert_active_order(order_3)
        |> OrderBook.enqueue_active_order(order_3)

      [book: book, order_1: order_1, order_2: order_2, order_3: order_3]
    end

    test "correctly closes a fullfilled ask", %{ book: book } do
      # Will match ask order of id: 3
      bid_order = %Order{id: 4, side: :bid, price: 150, qty: 300}

      { book, %Order{} = finalized_bid_order } = OrderBook.execute_order(book, bid_order, bid_order.price)

      assert finalized_bid_order.qty == 0
      assert OrderBook.get_active_order(book, 3) == nil
      assert PriceTree.has_price?(book.asks, 150) == false
    end

    test "correctly adjusts a bid order on partial fulfilment", %{ book: book } do
      # Will match ask order of id: 3
      bid_order = %Order{id: 4, side: :bid, price: 150, qty: 350}

      { book, %Order{} = finalized_bid_order } = OrderBook.execute_order(book, bid_order, bid_order.price)

      assert finalized_bid_order.qty == 50
      assert OrderBook.get_active_order(book, 3) == nil
      assert PriceTree.has_price?(book.asks, 150) == false
    end

    test "updates ask_order with remaining qty", %{ book: book } do
      # Will match ask order of id: 3
      bid_order = %Order{id: 4, side: :bid, price: 150, qty: 250}

      { book, %Order{} = finalized_bid_order } = OrderBook.execute_order(book, bid_order, bid_order.price)

      modified_ask_order = OrderBook.get_active_order(book, 3)

      assert finalized_bid_order.qty == 0
      assert modified_ask_order.qty == 50
      assert PriceTree.has_price?(book.asks, 150) == true
      assert OrderQueue.count(PriceTree.get_order_queue(book.asks, 150)) == 1
    end

  end
end
