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

    test "raises on inability of finding price_point", %{ book: book } do
      # Will not match any price points
      bid_order = %Order{id: 4, side: :bid, price: 125, qty: 250}

      assert_raise ArgumentError, fn -> OrderBook.execute_order(book, bid_order, bid_order.price) end
    end

  end

  describe "execute_order/3 for :ask order" do
    setup do
      order_1 = %Order{id: 1, side: :bid, price: 500, qty: 100}
      order_2 = %Order{id: 2, side: :bid, price: 500, qty: 150}
      order_3 = %Order{id: 3, side: :bid, price: 150, qty: 300}

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

    test "correctly closes a fullfilled bid", %{ book: book } do
      # Will match ask order of id: 3
      ask_order = %Order{id: 4, side: :ask, price: 150, qty: 300}

      { book, %Order{} = finalized_ask_order } = OrderBook.execute_order(book, ask_order, ask_order.price)

      assert finalized_ask_order.qty == 0
      assert OrderBook.get_active_order(book, 3) == nil
      assert PriceTree.has_price?(book.bids, 150) == false
    end

    test "correctly adjusts a bid order on partial fulfilment", %{ book: book } do
      # Will match ask order of id: 3
      ask_order = %Order{id: 4, side: :ask, price: 150, qty: 350}

      { book, %Order{} = finalized_ask_order } = OrderBook.execute_order(book, ask_order, ask_order.price)

      assert finalized_ask_order.qty == 50
      assert OrderBook.get_active_order(book, 3) == nil
      assert PriceTree.has_price?(book.bids, 150) == false
    end

    test "updates bid_order with remaining qty", %{ book: book } do
      # Will match ask order of id: 3
      ask_order = %Order{id: 4, side: :ask, price: 150, qty: 250}

      { book, %Order{} = finalized_ask_order } = OrderBook.execute_order(book, ask_order, ask_order.price)

      modified_bid_order = OrderBook.get_active_order(book, 3)

      assert finalized_ask_order.qty == 0
      assert modified_bid_order.qty == 50
      assert PriceTree.has_price?(book.bids, 150) == true
      assert OrderQueue.count(PriceTree.get_order_queue(book.bids, 150)) == 1
    end

    test "raises on inability of finding price_point", %{ book: book } do
      # Will not match any price points
      ask_order = %Order{id: 4, side: :ask, price: 125, qty: 250}

      assert_raise ArgumentError, fn -> OrderBook.execute_order(book, ask_order, ask_order.price) end
    end

  end

  describe "price_match/2 for bid order" do
    setup do
      order_1 = %Order{id: 1, side: :ask, price: 500, qty: 100}
      order_2 = %Order{id: 2, side: :ask, price: 500, qty: 150}
      order_3 = %Order{id: 3, side: :ask, price: 150, qty: 300}

      book_a = 
        OrderBook.new()
        |> OrderBook.insert_active_order(order_1)
        |> OrderBook.enqueue_active_order(order_1)
        |> OrderBook.insert_active_order(order_2)
        |> OrderBook.enqueue_active_order(order_2)
        |> OrderBook.insert_active_order(order_3)
        |> OrderBook.enqueue_active_order(order_3)

      book_b = 
        OrderBook.new()
        |> OrderBook.insert_active_order(order_1)
        |> OrderBook.enqueue_active_order(order_1)
        |> OrderBook.insert_active_order(order_2)
        |> OrderBook.enqueue_active_order(order_2)

      [book_a: book_a, book_b: book_b, order_1: order_1, order_2: order_2, order_3: order_3]
    end

    test "correctly closes matching bid order and associated enqueued active ask order", %{ book_a: book } do
      # Matches ask order #3
      order = %Order{ id: 4, side: :bid, price: 150, qty: 300 }

      assert PriceTree.has_price?(Map.get(book, :asks), 150) == true
      assert OrderBook.get_active_order(book, 3) != nil

      book = OrderBook.price_match(book, order)

      assert OrderBook.get_active_order(book, 4) == nil
      assert OrderBook.get_active_order(book, 3) == nil
      refute PriceTree.has_price?(book.asks, 150)
    end

    test "correctly closes single matching ask order", %{ book_b: book } do
      # Matches ask order #1
      order = %Order{ id: 4, side: :bid, price: 500, qty: 100 }

      book = OrderBook.price_match(book, order)

      assert OrderBook.get_active_order(book, 1) == nil
      assert OrderBook.get_active_order(book, 2) != nil
      assert PriceTree.has_price?(book.asks, 500) 
      assert OrderQueue.count(PriceTree.get_order_queue(book.asks, 500)) == 1
      assert OrderQueue.peek(PriceTree.get_order_queue(book.asks, 500)) == 2
    end

    test "correctly closes multiple matching ask orders", %{ book_b: book } do
      # Matches ask order #1 & #2
      order = %Order{ id: 4, side: :bid, price: 500, qty: 250 }

      book = OrderBook.price_match(book, order)

      assert OrderBook.get_active_order(book, 1) == nil
      assert OrderBook.get_active_order(book, 2) == nil
      refute PriceTree.has_price?(book.asks, 500) 
    end

    test "correctly closes one ask and partially closes second ask", %{ book_b: book } do
      # Matches order #1 & partial #2
      order = %Order{ id: 4, side: :bid, price: 500, qty: 225 }

      book = OrderBook.price_match(book, order)

      assert OrderBook.get_active_order(book, 1) == nil
      assert OrderBook.get_active_order(book, 2) != nil
      assert Map.get(OrderBook.get_active_order(book, 2), :qty) == 25
      assert PriceTree.has_price?(book.asks, 500) 
      assert OrderQueue.count(PriceTree.get_order_queue(book.asks, 500)) == 1
      assert OrderQueue.peek(PriceTree.get_order_queue(book.asks, 500)) == 2
    end

    test "correctly closes asks at multiple levels", %{ book_a: book } do
      # Matches orders #1 #2 & #3
      order = %Order{ id: 4, side: :bid, price: 550, qty: 550 }

      book = OrderBook.price_match(book, order)

      assert OrderBook.get_active_order(book, 1) == nil
      assert OrderBook.get_active_order(book, 2) == nil
      assert OrderBook.get_active_order(book, 3) == nil

      refute PriceTree.has_price?(book.asks, 500) 
      refute PriceTree.has_price?(book.asks, 150)
      assert PriceTree.is_empty?(book.asks)
    end

    test "correctly closes asks at multiple levels and adjusts final ask", %{ book_a: book } do
      # Matches orders #1 #2 partially & #3
      order = %Order{ id: 4, side: :bid, price: 550, qty: 500 }

      book = OrderBook.price_match(book, order)

      assert OrderBook.get_active_order(book, 1) == nil
      assert OrderBook.get_active_order(book, 2) != nil
      assert OrderBook.get_active_order(book, 3) == nil

      assert PriceTree.has_price?(book.asks, 500) 
      refute PriceTree.has_price?(book.asks, 150)
      assert OrderQueue.count(PriceTree.get_order_queue(book.asks, 500)) == 1
      assert OrderQueue.peek(PriceTree.get_order_queue(book.asks, 500)) == 2

      assert Map.get(OrderBook.get_active_order(book, 2), :qty) == 50
    end

    test "correctly enqueues order if no asks are found" do
      order = %Order{ id: 1, side: :bid, price: 550, qty: 500 }

      book = OrderBook.new()
             |> OrderBook.price_match(order)

      assert OrderBook.get_active_order(book, 1) == order
      assert PriceTree.has_price?(book.bids, 550)
      assert OrderQueue.count(PriceTree.get_order_queue(book.bids, 550)) == 1
      assert OrderQueue.peek(PriceTree.get_order_queue(book.bids, 550)) == 1 
    end
  end

  describe "price_match/2 for ask order" do
    setup do
      order_1 = %Order{id: 1, side: :bid, price: 150, qty: 100}
      order_2 = %Order{id: 2, side: :bid, price: 150, qty: 150}
      order_3 = %Order{id: 3, side: :bid, price: 500, qty: 300}

      book_a = 
        OrderBook.new()
        |> OrderBook.insert_active_order(order_1)
        |> OrderBook.enqueue_active_order(order_1)
        |> OrderBook.insert_active_order(order_2)
        |> OrderBook.enqueue_active_order(order_2)
        |> OrderBook.insert_active_order(order_3)
        |> OrderBook.enqueue_active_order(order_3)

      book_b = 
        OrderBook.new()
        |> OrderBook.insert_active_order(order_1)
        |> OrderBook.enqueue_active_order(order_1)
        |> OrderBook.insert_active_order(order_2)
        |> OrderBook.enqueue_active_order(order_2)

      [book_a: book_a, book_b: book_b, order_1: order_1, order_2: order_2, order_3: order_3]
    end

    test "correctly closes matching bid order and associated enqueued active bid order", %{ book_a: book } do
      # Matches ask order #3
      order = %Order{ id: 4, side: :ask, price: 500, qty: 300 }

      assert PriceTree.has_price?(Map.get(book, :bids), 500) == true
      assert OrderBook.get_active_order(book, 3) != nil

      book = OrderBook.price_match(book, order)

      assert OrderBook.get_active_order(book, 4) == nil
      assert OrderBook.get_active_order(book, 3) == nil
      refute PriceTree.has_price?(book.bids, 500)
    end

    test "correctly closes single matching bid order", %{ book_b: book } do
      # Matches ask order #1
      order = %Order{ id: 4, side: :ask, price: 150, qty: 100 }

      book = OrderBook.price_match(book, order)

      assert OrderBook.get_active_order(book, 1) == nil
      assert OrderBook.get_active_order(book, 2) != nil
      assert PriceTree.has_price?(book.bids, 150) 
      assert OrderQueue.count(PriceTree.get_order_queue(book.bids, 150)) == 1
      assert OrderQueue.peek(PriceTree.get_order_queue(book.bids, 150)) == 2
    end

    test "correctly closes multiple matching bid orders", %{ book_b: book } do
      # Matches ask order #1 & #2
      order = %Order{ id: 4, side: :ask, price: 150, qty: 250 }

      book = OrderBook.price_match(book, order)

      assert OrderBook.get_active_order(book, 1) == nil
      assert OrderBook.get_active_order(book, 2) == nil
      refute PriceTree.has_price?(book.bids, 150) 
    end

    test "correctly closes one bid and partially closes second bid", %{ book_b: book } do
      # Matches order #1 & partial #2
      order = %Order{ id: 4, side: :ask, price: 150, qty: 225 }

      book = OrderBook.price_match(book, order)

      assert OrderBook.get_active_order(book, 1) == nil
      assert OrderBook.get_active_order(book, 2) != nil
      assert Map.get(OrderBook.get_active_order(book, 2), :qty) == 25
      assert PriceTree.has_price?(book.bids, 150) 
      assert OrderQueue.count(PriceTree.get_order_queue(book.bids, 150)) == 1
      assert OrderQueue.peek(PriceTree.get_order_queue(book.bids, 150)) == 2
    end

    test "correctly closes bids at multiple levels", %{ book_a: book } do
      # Matches orders #1 #2 & #3
      order = %Order{ id: 4, side: :ask, price: 150, qty: 550 }

      book = OrderBook.price_match(book, order)

      assert OrderBook.get_active_order(book, 1) == nil
      assert OrderBook.get_active_order(book, 2) == nil
      assert OrderBook.get_active_order(book, 3) == nil

      refute PriceTree.has_price?(book.bids, 500) 
      refute PriceTree.has_price?(book.bids, 150)
      assert PriceTree.is_empty?(book.bids)
    end

    test "correctly closes bids at multiple levels and adjusts final bid", %{ book_a: book } do
      # Matches orders #1 #2 partially & #3
      order = %Order{ id: 4, side: :ask, price: 150, qty: 500 }

      book = OrderBook.price_match(book, order)

      assert OrderBook.get_active_order(book, 1) == nil
      assert OrderBook.get_active_order(book, 2) != nil
      assert OrderBook.get_active_order(book, 3) == nil

      assert PriceTree.has_price?(book.bids, 150) 
      refute PriceTree.has_price?(book.bids, 500)
      assert OrderQueue.count(PriceTree.get_order_queue(book.bids, 150)) == 1
      assert OrderQueue.peek(PriceTree.get_order_queue(book.bids, 150)) == 2

      assert Map.get(OrderBook.get_active_order(book, 2), :qty) == 50
    end

    test "correctly enqueues order if no asks are found" do
      order = %Order{ id: 1, side: :ask, price: 150, qty: 500 }

      book = OrderBook.new()
             |> OrderBook.price_match(order)

      assert OrderBook.get_active_order(book, 1) == order
      assert PriceTree.has_price?(book.asks, 150)
      assert OrderQueue.count(PriceTree.get_order_queue(book.asks, 150)) == 1
      assert OrderQueue.peek(PriceTree.get_order_queue(book.asks, 150)) == 1 
    end
  end

  describe "register_transaction/3 bid order" do

    test "registers one :bid_full_ask_full transaction" do
      book = OrderBook.new()
      op_order = %Order{id: 1, side: :bid, price: 150, qty: 100}
      re_order = %Order{id: 2, side: :ask, price: 100, qty: 100}

      book = OrderBook.register_transaction(book, op_order, re_order)

      assert Enum.count(book.completed_transactions) == 1

      transaction = List.first(book.completed_transactions)
      assert transaction.qty == 100
      assert transaction.bid_order == op_order
      assert transaction.ask_order == re_order
      assert transaction.price == 100
      assert transaction.type == :bid_full_ask_full
    end

    test "registers one :bid_full_ask_partial transaction" do
      book = OrderBook.new()
      op_order = %Order{id: 1, side: :bid, price: 150, qty: 100}
      re_order = %Order{id: 2, side: :ask, price: 100, qty: 150}

      book = OrderBook.register_transaction(book, op_order, re_order)

      assert Enum.count(book.completed_transactions) == 1

      transaction = List.first(book.completed_transactions)
      assert transaction.qty == 100
      assert transaction.bid_order == op_order
      assert transaction.ask_order == re_order
      assert transaction.price == 100
      assert transaction.type == :bid_full_ask_partial
    end

    test "registers one :bid_partial_ask_full transaction" do
      book = OrderBook.new()
      op_order = %Order{id: 1, side: :bid, price: 150, qty: 150}
      re_order = %Order{id: 2, side: :ask, price: 100, qty: 100}

      book = OrderBook.register_transaction(book, op_order, re_order)

      assert Enum.count(book.completed_transactions) == 1

      transaction = List.first(book.completed_transactions)
      assert transaction.qty == 100
      assert transaction.bid_order == op_order
      assert transaction.ask_order == re_order
      assert transaction.price == 100
      assert transaction.type == :bid_partial_ask_full
    end
  end

  describe "register_transaction/3 ask order" do

    test "registers one :ask_full_bid_full transaction" do
      book = OrderBook.new()
      op_order = %Order{id: 1, side: :ask, price: 100, qty: 100}
      re_order = %Order{id: 2, side: :bid, price: 250, qty: 100}

      book = OrderBook.register_transaction(book, op_order, re_order)

      assert Enum.count(book.completed_transactions) == 1

      transaction = List.first(book.completed_transactions)
      assert transaction.qty == 100
      assert transaction.ask_order == op_order
      assert transaction.bid_order == re_order
      assert transaction.price == 250
      assert transaction.type == :ask_full_bid_full
    end

    test "registers one :ask_full_bid_partial transaction" do
      book = OrderBook.new()
      op_order = %Order{id: 1, side: :ask, price: 100, qty: 100}
      re_order = %Order{id: 2, side: :bid, price: 250, qty: 150}

      book = OrderBook.register_transaction(book, op_order, re_order)

      assert Enum.count(book.completed_transactions) == 1

      transaction = List.first(book.completed_transactions)
      assert transaction.qty == 100
      assert transaction.ask_order == op_order
      assert transaction.bid_order == re_order
      assert transaction.price == 250
      assert transaction.type == :ask_full_bid_partial
    end

    test "registers one :ask_partial_bid_full transaction" do
      book = OrderBook.new()
      op_order = %Order{id: 1, side: :ask, price: 100, qty: 150}
      re_order = %Order{id: 2, side: :bid, price: 250, qty: 100}

      book = OrderBook.register_transaction(book, op_order, re_order)

      assert Enum.count(book.completed_transactions) == 1

      transaction = List.first(book.completed_transactions)
      assert transaction.qty == 100
      assert transaction.ask_order == op_order
      assert transaction.bid_order == re_order
      assert transaction.price == 250
      assert transaction.type == :ask_partial_bid_full
    end
  end

end
