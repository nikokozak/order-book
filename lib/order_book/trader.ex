defmodule Trader do
  defstruct [
    {:id, nil},
    {:active_orders, %{}},
    {:transactions, %{}}
  ]
end
