defmodule OrderBook.Transaction do
  alias OrderBook.Order

  defstruct [
    {:id, nil},
    {:bid_order, nil},
    {:ask_order, nil},
    {:price, nil},
    {:qty, nil},
    {:type, nil}, # :partial, :full
    {:acknowledged_at, DateTime.now("Etc/UTC")}
  ]

  def new(id, %Order{side: :ask} = op_ask_order, %Order{side: :bid} = re_bid_order) when is_number(id) do
    transaction_qty = min(op_ask_order.qty, re_bid_order.qty)

    %{ %__MODULE__{} | 
      id: id, 
      qty: transaction_qty,
      ask_order: op_ask_order,
      bid_order: re_bid_order,
      price: re_bid_order.price,
      type: cond do
        op_ask_order.qty > re_bid_order.qty -> :ask_partial_bid_full
        op_ask_order.qty == re_bid_order.qty -> :ask_full_bid_full
        op_ask_order.qty < re_bid_order.qty -> :ask_full_bid_partial
      end
    }
  end
  def new(id, %Order{side: :bid} = op_bid_order, %Order{side: :ask} = re_ask_order) when is_number(id) do
    transaction_qty = min(op_bid_order.qty, re_ask_order.qty)

    %{ %__MODULE__{} | 
      id: id, 
      qty: transaction_qty,
      bid_order: op_bid_order,
      ask_order: re_ask_order,
      price: re_ask_order.price,
      type: cond do
        op_bid_order.qty > re_ask_order.qty -> :bid_partial_ask_full
        op_bid_order.qty == re_ask_order.qty -> :bid_full_ask_full
        op_bid_order.qty < re_ask_order.qty -> :bid_full_ask_partial
      end
    }
  end
end
