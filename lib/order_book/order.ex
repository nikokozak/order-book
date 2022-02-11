defmodule OrderBook.Order do
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
