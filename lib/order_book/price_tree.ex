defmodule OrderBook.PriceTree do
  alias __MODULE__.Node

  defstruct root: nil, size: 0, less: &Kernel.</2

  @doc """
  Creates a new tree with default ascending order, preprogrammed to accept values in the `{price, queue}` format.

  ```
  iex> [{3, :a}, {4, :b}, {1, :c}, {2, :d}] |> Enum.into(PriceTree.new())
  #PriceTree<[{1, :c}, {2, :d}, {3, :a}, {4, :b}]>
  ```
  """
  @spec new() :: t()
  def new() do
    # %__MODULE__{}
    %__MODULE__{less: fn {a, _}, {b, _} -> a < b end}
  end

  @doc """
  Creates a new tree with the given `ordering` or comparison function.

  ```
  iex> [3, 1, 4, 2] |> Enum.into(PriceTree.new(:asc))
  #PriceTree<[1, 2, 3, 4]>
  iex> [3, 1, 4, 2] |> Enum.into(PriceTree.new(:desc))
  #PriceTree<[4, 3, 2, 1]>
  iex> [3, 1, 4, 2] |> Enum.into(PriceTree.new(fn a, b -> a > b end))
  #PriceTree<[4, 3, 2, 1]>
  ```
  """
  @spec new(:asc | :desc | less()) :: t()
  def new(ordering) when is_function(ordering) do
    %__MODULE__{less: ordering}
  end

  def new(:asc) do
    %__MODULE__{less: fn {a, _}, {b, _} -> a < b end}
  end

  def new(:desc) do
    %__MODULE__{less: fn {a, _}, {b, _} -> a > b end}
  end

  @doc """
  Returns `true` if the given `price` has been registered in the tree. Otherwise returns `false`.
  """
  def has_price?(%__MODULE__{} = tree, price) when is_number(price) do
    member?(tree, {price, nil})
  end

  @doc """
  Removes a price level from the price tree. 

  Returns the price tree.
  """
  def remove_price(%__MODULE__{} = tree, price) when is_number(price) do
    delete(tree, {price, nil})
  end

  @doc """
  Returns a queue of orders at the given `price` level. Returns nil if price hasn't been registered.
  """
  def get_order_queue(%__MODULE__{} = tree, price) when is_number(price) do
    case get(tree, {price, nil}) do
      {_price, order_queue} -> order_queue
      nil -> nil
    end
  end

  @doc """
  Assigns an `order_queue` to a given `price`. Replaces the existing `order_queue` if it exists.
  """
  def put_order_queue(%__MODULE__{} = tree, price, order_queue) when is_number(price) do
    put(tree, {price, order_queue})
  end

  @doc """
  Updates an order queue at a given `price` level if it exists, using the `func` function, which is passed the order queue.
  """
  def update_order_queue(%__MODULE__{} = tree, price, func) when is_number(price) and is_function(func) do
    orders = get_order_queue(tree, price)
    if is_nil(orders), do: nil, else: put_order_queue(tree, price, func.(orders))
  end

  @doc """
  Returns the minimum registered price level.
  """
  def lowest_price(%__MODULE__{} = tree) do
    get_first(tree, {nil, nil}) |> elem(0)
  end

  @doc """
  Returns the highest registered price level.
  """
  def highest_price(%__MODULE__{} = tree) do
    get_last(tree, {nil, nil}) |> elem(0)
  end

  @doc """
  Returns height of the tree.

  ```
  iex> tree = [5, 9, 3, 8, 1, 6, 7] |> Enum.into(PriceTree.new())
  #PriceTree<[1, 3, 5, 6, 7, 8, 9]>
  iex> PriceTree.height(tree)
  4
  ```
  """
  @spec height(t()) :: integer()
  def height(%__MODULE__{root: root}) do
    Node.height(root)
  end

  @doc """
  Returns the number of elements in the tree

  ```
  iex> tree = [5, 9, 3, 8, 1, 6, 7] |> Enum.into(PriceTree.new())
  #PriceTree<[1, 3, 5, 6, 7, 8, 9]>
  iex> PriceTree.size(tree)
  7
  ```
  """
  @spec size(t()) :: integer()
  def size(%__MODULE__{size: size}) do
    size
  end

  @doc """
  Retrieves an element equal to `value`.

  If the tree contains more than one element equal to `value`, retrieves one of them. It is undefined which one.

  Returns `defailt` if nothing is found.

  ```
  iex> tree = PriceTree.new(fn {a, _}, {b, _} -> a < b end)
  #PriceTree<[]>
  iex> tree = [a: "A", c: "C", d: "D", b: "B"] |> Enum.into(tree)
  #PriceTree<[a: "A", b: "B", c: "C", d: "D"]>
  iex> PriceTree.get(tree, {:c, nil}, :error)
  {:c, "C"}
  iex> PriceTree.get(tree, {:e, nil}, :error)
  :error
  ```
  """
  @spec get(t(), value(), term()) :: value() | term()
  def get(%__MODULE__{root: root, less: less}, value, default \\ nil) do
    Node.get(root, value, default, less)
  end

  @doc """
  Returns `true` if the tree is empty.

  Otherwise returns false.

  ```
  iex> tree = [] |> Enum.into(PriceTree.new())
  #PriceTree<[]>
  iex> PriceTree.is_empty?(tree)
  true
  """
  def is_empty?(%__MODULE__{root: root}) do
    if Node.get_first(root, false) do
      false
    else
      true
    end
  end

  @doc """
  Retrieves the first value in the tree.

  Returns `default` if the tree is empty.

  ```
  iex> tree = [3, 2, 4, 6] |> Enum.into(PriceTree.new())
  #PriceTree<[2, 3, 4, 6]>
  iex> PriceTree.get_first(tree)
  2
  ```
  """
  @spec get_first(t(), term()) :: value() | term()
  def get_first(%__MODULE__{root: root}, default \\ nil) do
    Node.get_first(root, default)
  end

  @doc """
  Retrieves the last value in the tree.

  Returns `default` if the tree is empty.

  ```
  iex> tree = [3, 2, 4, 6] |> Enum.into(PriceTree.new())
  #PriceTree<[2, 3, 4, 6]>
  iex> PriceTree.get_last(tree)
  6
  ```
  """
  @spec get_last(t(), term()) :: value() | term()
  def get_last(%__MODULE__{root: root}, default \\ nil) do
    Node.get_last(root, default)
  end

  @doc """
  Retrieves an element equal to `value`.

  If the tree contains more than one element equal to `value`, retrieves the first of them

  Returns `default` if nothing is found.

  ```
  iex> tree = [b: 21, a: 1, b: 22, c: 3, b: 23] |> Enum.into(PriceTree.new(fn {a, _}, {b, _} -> a < b end))
  #PriceTree<[a: 1, b: 21, b: 22, b: 23, c: 3]>
  iex> PriceTree.get_lower(tree, {:b, nil})
  {:b, 21}
  ```
  """
  @spec get_lower(t(), value(), term()) :: value() | term()
  def get_lower(%__MODULE__{root: root, less: less}, value, default \\ nil) do
    Node.get_lower(root, value, default, less)
  end

  @doc """
  Retrieves an element equal to `value`.

  If the tree contains more than one element equal to `value`, retrieves the last of them

  Returns `default` if nothing is found.

  ```
  iex> tree = [b: 21, a: 1, b: 22, c: 3, b: 23] |> Enum.into(PriceTree.new(fn {a, _}, {b, _} -> a < b end))
  #PriceTree<[a: 1, b: 21, b: 22, b: 23, c: 3]>
  iex> PriceTree.get_upper(tree, {:b, nil})
  {:b, 23}
  ```
  """
  @spec get_upper(t(), value(), term()) :: value() | term()
  def get_upper(%__MODULE__{root: root, less: less}, value, default \\ nil),
    do: Node.get_upper(root, value, default, less)

  @doc """
  Checks if the tree contains an element equal to `value`.

  ```
  iex> tree = [3, 2, 4, 6] |> Enum.into(PriceTree.new())
  #PriceTree<[2, 3, 4, 6]>
  iex> PriceTree.member?(tree, 4)
  true
  iex> PriceTree.member?(tree, 1)
  false
  ```
  """
  @spec member?(t(), term()) :: boolean()
  def member?(%__MODULE__{root: root, less: less}, value), do: Node.member?(root, value, less)

  @doc """
  Puts the given `value` in the tree.

  If the tree already contains elements equal to `value`, replaces one of them. It is undefined which one.

  ```
  iex> tree = [b: 2, a: 1, c: 3] |> Enum.into(PriceTree.new(fn {a, _}, {b, _} -> a < b end))
  #PriceTree<[a: 1, b: 2, c: 3]>
  iex> PriceTree.put(tree, {:d, 4})
  #PriceTree<[a: 1, b: 2, c: 3, d: 4]>
  iex> PriceTree.put(tree, {:a, 11})
  #PriceTree<[a: 11, b: 2, c: 3]>
  ```
  """
  @spec put(t(), value()) :: t()
  def put(%__MODULE__{root: root, size: size, less: less} = avl_tree, value) do
    case Node.put(root, value, less) do
      {:update, root} -> %{avl_tree | root: root}
      root -> %{avl_tree | root: root, size: size + 1}
    end
  end

  @doc """
  Puts the given `value` in the tree.

  If the tree already contains elements equal to `value`, inserts `value` before them.

  ```
  iex> tree = [b: 21, a: 11, d: 41, c: 31] |> Enum.into(PriceTree.new(fn {a, _}, {b, _} -> a < b end))
  #PriceTree<[a: 11, b: 21, c: 31, d: 41]>
  iex> tree = PriceTree.put_lower(tree, {:a, 12})
  #PriceTree<[a: 12, a: 11, b: 21, c: 31, d: 41]>
  iex> tree = PriceTree.put_lower(tree, {:b, 22})
  #PriceTree<[a: 12, a: 11, b: 22, b: 21, c: 31, d: 41]>
  iex> PriceTree.put_lower(tree, {:d, 42})
  #PriceTree<[a: 12, a: 11, b: 22, b: 21, c: 31, d: 42, d: 41]>
  ```
  """
  @spec put_lower(t(), value()) :: t()
  def put_lower(%__MODULE__{root: root, size: size, less: less} = avl_tree, value) do
    %{avl_tree | root: Node.put_lower(root, value, less), size: size + 1}
  end

  @doc """
  Puts the given `value` in the tree.

  If the tree already contains elements equal to `value`, inserts `value` after them.
  ```
  iex> tree = [b: 21, a: 11, d: 41, c: 31] |> Enum.into(PriceTree.new(fn {a, _}, {b, _} -> a < b end))
  #PriceTree<[a: 11, b: 21, c: 31, d: 41]>
  iex> tree = PriceTree.put_upper(tree, {:a, 12})
  #PriceTree<[a: 11, a: 12, b: 21, c: 31, d: 41]>
  iex> tree = PriceTree.put_upper(tree, {:b, 22})
  #PriceTree<[a: 11, a: 12, b: 21, b: 22, c: 31, d: 41]>
  iex> PriceTree.put_upper(tree, {:d, 42})
  #PriceTree<[a: 11, a: 12, b: 21, b: 22, c: 31, d: 41, d: 42]>
  ```

  `Enum.into/2` uses `put_upper/2`:

  ```
  iex> [a: 11, c: 31, a: 12, b: 21, a: 13] |> Enum.into(PriceTree.new(fn {a, _}, {b, _} -> a < b end)) |> Enum.to_list()
  [a: 11, a: 12, a: 13, b: 21, c: 31]
  ```
  """
  @spec put_upper(t(), value()) :: t()
  def put_upper(%__MODULE__{root: root, size: size, less: less} = avl_tree, value) do
    %{avl_tree | root: Node.put_upper(root, value, less), size: size + 1}
  end

  @doc """
  Deletes an element equal to the given `value`.

  If the tree contains more than one element equal to `value`, deletes one of them. It is undefined which one.

  If no element is found, returns the tree unchanged.

  ```
  iex> tree = [3, 2, 1, 4] |> Enum.into(PriceTree.new())
  #PriceTree<[1, 2, 3, 4]>
  iex> PriceTree.delete(tree, 3)
  #PriceTree<[1, 2, 4]>
  iex> PriceTree.delete(tree, 5)
  #PriceTree<[1, 2, 3, 4]>
  ```
  """
  @spec delete(t(), value()) :: t()
  def delete(%__MODULE__{root: root, size: size, less: less} = avl_tree, value) do
    case Node.delete(root, value, less) do
      {true, a} -> %{avl_tree | root: a, size: size - 1}
      {false, _} -> avl_tree
    end
  end

  @doc """
  Deletes an element equal to the given `value`.

  If the tree contains more than one element equal to `value`, deletes the first of them.

  If no element is found, returns the tree unchanged.

  ```
  iex> tree = [b: 21, a: 1, b: 22, c: 3, b: 23] |> Enum.into(PriceTree.new(fn {a, _}, {b, _} -> a < b end))
  #PriceTree<[a: 1, b: 21, b: 22, b: 23, c: 3]>
  iex> PriceTree.delete_lower(tree, {:b, nil})
  #PriceTree<[a: 1, b: 22, b: 23, c: 3]>
  ```
  """
  def delete_lower(%__MODULE__{root: root, size: size, less: less} = avl_tree, value) do
    case Node.delete_lower(root, value, less) do
      {true, a} -> %{avl_tree | root: a, size: size - 1}
      {false, _} -> avl_tree
    end
  end

  @doc """
  Deletes an element equal to the given `value`.

  If the tree contains more than one element equal to `value`, deletes the last of them.

  If no element is found, returns the tree unchanged.

  ```
  iex> tree = [b: 21, a: 1, b: 22, c: 3, b: 23] |> Enum.into(PriceTree.new(fn {a, _}, {b, _} -> a < b end))
  #PriceTree<[a: 1, b: 21, b: 22, b: 23, c: 3]>
  iex> PriceTree.delete_upper(tree, {:b, nil})
  #PriceTree<[a: 1, b: 21, b: 22, c: 3]>
  ```
  """
  def delete_upper(%__MODULE__{root: root, size: size, less: less} = avl_tree, value) do
    case Node.delete_upper(root, value, less) do
      {true, a} -> %{avl_tree | root: a, size: size - 1}
      {false, _} -> avl_tree
    end
  end

  @doc """
  Displays the tree in human readable form.

  ```
  iex> tree = 1..10 |> Enum.into(PriceTree.new())
  #PriceTree<[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]>
  iex> IO.puts PriceTree.view(tree)
  ```
  ```shell
     4
   ┌─┴───┐
   2     8
  ┌┴┐  ┌─┴─┐
  1 3  6   9
      ┌┴┐ ┌┴─┐
      5 7   10
  ```
  """
  @spec view(t()) :: String.t()
  def view(%__MODULE__{root: root}) do
    Node.view(root)
  end

  defimpl Enumerable do
    import OrderBook.PriceTree.Node, only: [iter_lower: 1, next: 1, value: 1]

    def reduce(%OrderBook.PriceTree{root: root}, {:cont, acc}, fun) do
      iter_lower(root) |> next() |> reduce({:cont, acc}, fun)
    end

    def reduce(iter, {state, acc}, fun) do
      case state do
        :halt ->
          {:halted, acc}

        :suspend ->
          {:suspended, acc, &reduce(iter, &1, fun)}

        :cont ->
          case iter do
            :none -> {:done, acc}
            {e, iter} -> reduce(next(iter), fun.(value(e), acc), fun)
          end
      end
    end

    def member?(%OrderBook.PriceTree{} = tree, value) do
      {:ok, OrderBook.PriceTree.member?(tree, value)}
    end

    def count(%OrderBook.PriceTree{size: size}) do
      {:ok, size}
    end

    def slice(_) do
      {:error, __MODULE__}
    end
  end

  defimpl Collectable do
    def into(original) do
      {
        original,
        fn
          tree, {:cont, value} -> OrderBook.PriceTree.put_upper(tree, value)
          tree, :done -> tree
          _, :halt -> :ok
        end
      }
    end
  end

  @opaque t() :: %__MODULE__{}
  @type value() :: term()
  @type less() :: (value(), value() -> boolean())
end

defimpl Inspect, for: OrderBook.PriceTree do
  def inspect(%OrderBook.PriceTree{} = tree, opts) do
    cnt = tree |> Enum.take(opts.limit + 1) |> Enum.to_list() |> inspect
    "#PriceTree<#{cnt}>"
  end
end
