defmodule OrderBook.OrderQueue do

  defstruct value: :queue.new()

  def count(%__MODULE__{} = queue) do
    :queue.len(queue.value)
  end

  def push(%__MODULE__{} = queue, order_id) when is_number(order_id) do
    %{ queue | value: :queue.in(order_id, queue.value) }
  end

  def pop(%__MODULE__{} = queue) do
    {{:value, val}, popped_queue} = :queue.out(queue.value)
    {val, %{ queue | value: popped_queue }}
  end

  def advance(%__MODULE__{} = queue) do
    {{:value, _val}, popped_queue} = :queue.out(queue.value)
    %{ queue | value: popped_queue }
  end

  def peek(%__MODULE__{} = queue) do
    :queue.peek(queue.value) |> elem(1)
  end

  def delete(%__MODULE__{} = queue, order_id) when is_number(order_id) do
    %{ queue | value: :queue.delete_with(fn id -> id == order_id end, queue.value) }
  end

  def is_empty?(%__MODULE__{} = queue) do
    :queue.is_empty(queue.value)
  end

end
