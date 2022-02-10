defmodule PriceTreeTest do
  use ExUnit.Case
  alias OrderBook.PriceTree

  doctest PriceTree, except: [view: 1]

  use ExUnit.Case

  test "protocols" do
    tree1 = Enum.into([5, 9, 3, 8, 1, 6, 7], PriceTree.new())
    assert Enum.to_list(tree1) == [1, 3, 5, 6, 7, 8, 9]
    assert Enum.member?(tree1, 6)
    assert !Enum.member?(tree1, 10)
    tree2 = Enum.into([8, 4, 2, 5, 7, 2, 1, 3], PriceTree.new())
    assert Enum.to_list(tree2) == [1, 2, 2, 3, 4, 5, 7, 8]
    assert Enum.zip(tree1, tree2) == [{1, 1}, {3, 2}, {5, 2}, {6, 3}, {7, 4}, {8, 5}, {9, 7}]
  end

  test "new" do
    asc = &Kernel.</2
    desc = &Kernel.>/2

    %PriceTree{root: nil, size: 0, less: ^asc} = PriceTree.new()
    %PriceTree{root: nil, size: 0, less: ^asc} = PriceTree.new(:asc)
    %PriceTree{root: nil, size: 0, less: ^desc} = PriceTree.new(:desc)
  end

  test "put" do
    tree = Enum.into([5, 9, 3, 8, 1, 6, 7], PriceTree.new())
    assert Enum.to_list(tree) == [1, 3, 5, 6, 7, 8, 9]
    assert PriceTree.member?(tree, 3)
    assert !PriceTree.member?(tree, 2)

    assert PriceTree.size(tree) == 7
    assert PriceTree.height(tree) == 4

    assert inspect(tree) == "#PriceTree<[1, 3, 5, 6, 7, 8, 9]>"

    #    5
    #  ┌─┴───┐
    #  3     8
    # ┌┴┐  ┌─┴┐
    # 1    6  9
    #     ┌┴┐
    #       7
    assert tree.root ==
             {5, 4, {3, 2, {1, 1, nil, nil}, nil},
              {8, 3, {6, 2, nil, {7, 1, nil, nil}}, {9, 1, nil, nil}}}

    tree = Enum.into([11, 10, 12], tree)
    assert Enum.to_list(tree) == [1, 3, 5, 6, 7, 8, 9, 10, 11, 12]
    assert PriceTree.size(tree) == 10
    assert PriceTree.height(tree) == 4

    #        8
    #    ┌───┴─┐
    #    5    10
    #  ┌─┴─┐  ┌┴─┐
    #  3   6  9 11
    # ┌┴┐ ┌┴┐   ┌┴─┐
    # 1     7     12
    assert tree.root ==
             {8, 4, {5, 3, {3, 2, {1, 1, nil, nil}, nil}, {6, 2, nil, {7, 1, nil, nil}}},
              {10, 3, {9, 1, nil, nil}, {11, 2, nil, {12, 1, nil, nil}}}}

    tree = PriceTree.put(tree, 4)
    assert Enum.to_list(tree) == [1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    assert PriceTree.size(tree) == 11
    assert PriceTree.height(tree) == 4

    #        8
    #    ┌───┴─┐
    #    5    10
    #  ┌─┴─┐  ┌┴─┐
    #  3   6  9 11
    # ┌┴┐ ┌┴┐   ┌┴─┐
    # 1 4   7     12
    assert tree.root ==
             {8, 4,
              {5, 3, {3, 2, {1, 1, nil, nil}, {4, 1, nil, nil}}, {6, 2, nil, {7, 1, nil, nil}}},
              {10, 3, {9, 1, nil, nil}, {11, 2, nil, {12, 1, nil, nil}}}}

    assert tree == PriceTree.put(tree, 7)
  end

  test "get" do
    tree =
      [{5, 50}, {1, 10}, {9, 90}, {1, 20}, {5, 40}, {7, 70}, {2, 20}]
      |> Enum.into(PriceTree.new(fn {k1, _}, {k2, _} -> k1 < k2 end))

    assert PriceTree.get(tree, {7, nil}) == {7, 70}
    assert PriceTree.get(tree, {9, nil}) == {9, 90}
    assert PriceTree.get(tree, {5, nil}) == {5, 50}
    assert PriceTree.get(tree, {1, nil}) == {1, 20}
    assert PriceTree.get(tree, {6, nil}) == nil
    assert PriceTree.get(tree, {6, nil}, :error) == :error
  end

  test "get first/last" do
    tree =
      [{5, 50}, {1, 10}, {9, 90}, {1, 20}, {5, 40}, {7, 70}, {2, 20}]
      |> Enum.into(PriceTree.new(fn {k1, _}, {k2, _} -> k1 < k2 end))

    assert PriceTree.get_first(tree) == {1, 10}
    assert PriceTree.get_last(tree) == {9, 90}

    tree = PriceTree.new()
    assert PriceTree.get_first(tree) == nil
    assert PriceTree.get_first(tree, :error) == :error

    assert PriceTree.get_last(tree) == nil
    assert PriceTree.get_last(tree, :error) == :error
  end

  test "get lower/upper" do
    tree =
      [{5, 50}, {1, 10}, {9, 90}, {1, 20}, {5, 40}, {7, 70}, {2, 20}]
      |> Enum.into(PriceTree.new(fn {k1, _}, {k2, _} -> k1 < k2 end))

    assert PriceTree.get_lower(tree, {1, nil}) == {1, 10}
    assert PriceTree.get_upper(tree, {1, nil}) == {1, 20}

    assert PriceTree.get_lower(tree, {5, nil}) == {5, 50}
    assert PriceTree.get_upper(tree, {5, nil}) == {5, 40}

    assert PriceTree.get_lower(tree, {6, nil}) == nil
    assert PriceTree.get_upper(tree, {6, nil}) == nil

    assert PriceTree.get_lower(tree, {6, nil}, :error) == :error
    assert PriceTree.get_upper(tree, {6, nil}, :error) == :error
  end

  test "put/delete lower/upper" do
    tree =
      [{1, 10}, {5, 50}, {9, 90}, {7, 70}, {2, 20}]
      |> Enum.into(PriceTree.new(fn {k1, _}, {k2, _} -> k1 < k2 end))

    assert Enum.to_list(tree) == [{1, 10}, {2, 20}, {5, 50}, {7, 70}, {9, 90}]
    assert PriceTree.size(tree) == 5
    assert PriceTree.height(tree) == 3

    #         {5, 50}
    #    ┌───────┴───────┐
    # {1, 10}         {9, 90}
    #   ┌┴───┐       ┌───┴┐
    #     {2, 20} {7, 70}
    assert tree.root ==
             {{5, 50}, 3, {{1, 10}, 2, nil, {{2, 20}, 1, nil, nil}},
              {{9, 90}, 2, {{7, 70}, 1, nil, nil}, nil}}

    tree = PriceTree.put(tree, {7, 700})
    assert Enum.to_list(tree) == [{1, 10}, {2, 20}, {5, 50}, {7, 700}, {9, 90}]
    assert PriceTree.size(tree) == 5
    assert PriceTree.height(tree) == 3

    #         {5, 50}
    #    ┌───────┴────────┐
    # {1, 10}          {9, 90}
    #   ┌┴───┐        ┌───┴┐
    #     {2, 20} {7, 700}
    assert tree.root ==
             {{5, 50}, 3, {{1, 10}, 2, nil, {{2, 20}, 1, nil, nil}},
              {{9, 90}, 2, {{7, 700}, 1, nil, nil}, nil}}

    assert PriceTree.put_lower(tree, {8, 80}) == PriceTree.put_upper(tree, {8, 80})
    assert PriceTree.put_lower(tree, {8, 80}) == PriceTree.put(tree, {8, 80})

    tree = PriceTree.put_lower(tree, {7, 71})
    tree = PriceTree.put_lower(tree, {7, 72})
    tree = PriceTree.put_lower(tree, {7, 73})

    assert Enum.to_list(tree) == [
             {1, 10},
             {2, 20},
             {5, 50},
             {7, 73},
             {7, 72},
             {7, 71},
             {7, 700},
             {9, 90}
           ]

    assert PriceTree.size(tree) == 8
    assert PriceTree.height(tree) == 4

    #         {5, 50}
    #    ┌───────┴───────────────┐
    # {1, 10}                {7, 700}
    #   ┌┴───┐           ┌───────┴───┐
    #     {2, 20}     {7, 72}     {9, 90}
    #                ┌───┴───┐
    #             {7, 73} {7, 71}
    assert tree.root ==
             {{5, 50}, 4, {{1, 10}, 2, nil, {{2, 20}, 1, nil, nil}},
              {{7, 700}, 3, {{7, 72}, 2, {{7, 73}, 1, nil, nil}, {{7, 71}, 1, nil, nil}},
               {{9, 90}, 1, nil, nil}}}

    tree = PriceTree.put_upper(tree, {7, 74})
    tree = PriceTree.put_upper(tree, {7, 75})
    tree = PriceTree.put_upper(tree, {7, 76})

    assert Enum.to_list(tree) == [
             {1, 10},
             {2, 20},
             {5, 50},
             {7, 73},
             {7, 72},
             {7, 71},
             {7, 700},
             {7, 74},
             {7, 75},
             {7, 76},
             {9, 90}
           ]

    #                        {7, 700}
    #            ┌───────────────┴───────┐
    #         {5, 50}                 {7, 75}
    #    ┌───────┴───────┐           ┌───┴───────┐
    # {1, 10}         {7, 72}     {7, 74}     {9, 90}
    #   ┌┴───┐       ┌───┴───┐               ┌───┴┐
    #     {2, 20} {7, 73} {7, 71}         {7, 76}
    assert tree.root ==
             {{7, 700}, 4,
              {{5, 50}, 3, {{1, 10}, 2, nil, {{2, 20}, 1, nil, nil}},
               {{7, 72}, 2, {{7, 73}, 1, nil, nil}, {{7, 71}, 1, nil, nil}}},
              {{7, 75}, 3, {{7, 74}, 1, nil, nil}, {{9, 90}, 2, {{7, 76}, 1, nil, nil}, nil}}}

    tree = PriceTree.delete_upper(tree, {7, nil})

    #                        {7, 700}
    #            ┌───────────────┴───────┐
    #         {5, 50}                 {7, 75}
    #    ┌───────┴───────┐           ┌───┴───┐
    # {1, 10}         {7, 72}     {7, 74} {9, 90}
    #   ┌┴───┐       ┌───┴───┐
    #     {2, 20} {7, 73} {7, 71}
    assert tree.root ==
             {{7, 700}, 4,
              {{5, 50}, 3, {{1, 10}, 2, nil, {{2, 20}, 1, nil, nil}},
               {{7, 72}, 2, {{7, 73}, 1, nil, nil}, {{7, 71}, 1, nil, nil}}},
              {{7, 75}, 2, {{7, 74}, 1, nil, nil}, {{9, 90}, 1, nil, nil}}}

    tree = PriceTree.delete_lower(tree, {7, nil})

    #                    {7, 700}
    #            ┌───────────┴───────┐
    #         {5, 50}             {7, 75}
    #    ┌───────┴───┐           ┌───┴───┐
    # {1, 10}     {7, 72}     {7, 74} {9, 90}
    #   ┌┴───┐      ┌┴───┐
    #     {2, 20}     {7, 71}
    assert tree.root ==
             {{7, 700}, 4,
              {{5, 50}, 3, {{1, 10}, 2, nil, {{2, 20}, 1, nil, nil}},
               {{7, 72}, 2, nil, {{7, 71}, 1, nil, nil}}},
              {{7, 75}, 2, {{7, 74}, 1, nil, nil}, {{9, 90}, 1, nil, nil}}}

    tree = PriceTree.delete_lower(tree, {7, nil})

    #                {7, 700}
    #            ┌───────┴───────┐
    #         {5, 50}         {7, 75}
    #    ┌───────┴───┐       ┌───┴───┐
    # {1, 10}     {7, 71} {7, 74} {9, 90}
    #   ┌┴───┐
    #     {2, 20}
    assert tree.root ==
             {{7, 700}, 4,
              {{5, 50}, 3, {{1, 10}, 2, nil, {{2, 20}, 1, nil, nil}}, {{7, 71}, 1, nil, nil}},
              {{7, 75}, 2, {{7, 74}, 1, nil, nil}, {{9, 90}, 1, nil, nil}}}

    tree = PriceTree.delete_lower(tree, {7, nil})

    #            {7, 700}
    #        ┌───────┴───────┐
    #     {2, 20}         {7, 75}
    #    ┌───┴───┐       ┌───┴───┐
    # {1, 10} {5, 50} {7, 74} {9, 90}
    assert tree.root ==
             {{7, 700}, 3, {{2, 20}, 2, {{1, 10}, 1, nil, nil}, {{5, 50}, 1, nil, nil}},
              {{7, 75}, 2, {{7, 74}, 1, nil, nil}, {{9, 90}, 1, nil, nil}}}

    tree = PriceTree.delete_upper(tree, {7, nil})

    #            {7, 700}
    #        ┌───────┴───┐
    #     {2, 20}     {7, 74}
    #    ┌───┴───┐      ┌┴───┐
    # {1, 10} {5, 50}     {9, 90}

    assert tree.root ==
             {{7, 700}, 3, {{2, 20}, 2, {{1, 10}, 1, nil, nil}, {{5, 50}, 1, nil, nil}},
              {{7, 74}, 2, nil, {{9, 90}, 1, nil, nil}}}

    assert ^tree = PriceTree.delete_upper(tree, {6, nil})
    assert ^tree = PriceTree.delete_lower(tree, {6, nil})
  end

  test "delete" do
    tree = Enum.into([5, 9, 3, 8, 1, 6, 7], PriceTree.new())
    assert match?(^tree, PriceTree.delete(tree, 4))
    tree = PriceTree.delete(tree, 3)

    assert Enum.to_list(tree) == [1, 5, 6, 7, 8, 9]
    assert PriceTree.size(tree) == 6
    assert PriceTree.height(tree) == 3

    #    6
    #  ┌─┴─┐
    #  5   8
    # ┌┴┐ ┌┴┐
    # 1   7 9
    assert tree.root ==
             {6, 3, {5, 2, {1, 1, nil, nil}, nil}, {8, 2, {7, 1, nil, nil}, {9, 1, nil, nil}}}

    tree = PriceTree.delete(tree, 1)
    assert Enum.to_list(tree) == [5, 6, 7, 8, 9]
    assert PriceTree.size(tree) == 5 and PriceTree.height(tree) == 3

    #  6
    # ┌┴─┐
    # 5  8
    #   ┌┴┐
    #   7 9
    assert tree.root == {6, 3, {5, 1, nil, nil}, {8, 2, {7, 1, nil, nil}, {9, 1, nil, nil}}}

    tree = PriceTree.delete(tree, 8)
    assert Enum.to_list(tree) == [5, 6, 7, 9]
    assert PriceTree.size(tree) == 4 and PriceTree.height(tree) == 3

    #  6
    # ┌┴─┐
    # 5  7
    #   ┌┴┐
    #     9
    assert tree.root == {6, 3, {5, 1, nil, nil}, {7, 2, nil, {9, 1, nil, nil}}}

    tree = Enum.into([3, 1, 2, 4, 8, 0], tree)
    assert Enum.to_list(tree) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    assert PriceTree.size(tree) == 10 and PriceTree.height(tree) == 4

    #        6
    #    ┌───┴─┐
    #    3     8
    #  ┌─┴─┐  ┌┴┐
    #  1   5  7 9
    # ┌┴┐ ┌┴┐
    # 0 2 4
    assert tree.root ==
             {6, 4,
              {3, 3, {1, 2, {0, 1, nil, nil}, {2, 1, nil, nil}}, {5, 2, {4, 1, nil, nil}, nil}},
              {8, 2, {7, 1, nil, nil}, {9, 1, nil, nil}}}

    tree = PriceTree.delete(tree, 6)
    assert Enum.to_list(tree) == [0, 1, 2, 3, 4, 5, 7, 8, 9]
    assert PriceTree.size(tree) == 9 and PriceTree.height(tree) == 4

    #      5
    #    ┌─┴─┐
    #    3   8
    #  ┌─┴┐ ┌┴┐
    #  1  4 7 9
    # ┌┴┐
    # 0 2
    assert tree.root ==
             {5, 4, {3, 3, {1, 2, {0, 1, nil, nil}, {2, 1, nil, nil}}, {4, 1, nil, nil}},
              {8, 2, {7, 1, nil, nil}, {9, 1, nil, nil}}}

    tree = Enum.into([0, 3, 2, 1, 4, 8, 7, 9, 5, 6, 11, 12, 10, 14, 13, 15], PriceTree.new())
    tree = PriceTree.delete(tree, 4)
    assert Enum.to_list(tree) == [0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    assert PriceTree.size(tree) == 15 and PriceTree.height(tree) == 5

    #      5
    #    ┌─┴──────┐
    #    2       11
    #  ┌─┴┐  ┌────┴──┐
    #  0  3  7      13
    # ┌┴┐   ┌┴─┐    ┌┴─┐
    #   1   6  9   12 14
    #         ┌┴─┐    ┌┴─┐
    #         8 10      15
    assert tree.root ==
             {5, 5, {2, 3, {0, 2, nil, {1, 1, nil, nil}}, {3, 1, nil, nil}},
              {11, 4, {7, 3, {6, 1, nil, nil}, {9, 2, {8, 1, nil, nil}, {10, 1, nil, nil}}},
               {13, 3, {12, 1, nil, nil}, {14, 2, nil, {15, 1, nil, nil}}}}}

    tree = tree |> PriceTree.delete(3) |> PriceTree.delete(2)
    assert Enum.to_list(tree) == [0, 1, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

    assert PriceTree.size(tree) == 13 and PriceTree.height(tree) == 5

    #          11
    #    ┌──────┴──┐
    #    5        13
    #  ┌─┴─┐      ┌┴─┐
    #  1   7     12 14
    # ┌┴┐ ┌┴─┐      ┌┴─┐
    # 0   6  9        15
    #       ┌┴─┐
    #       8 10
    assert tree.root ==
             {11, 5,
              {5, 4, {1, 2, {0, 1, nil, nil}, nil},
               {7, 3, {6, 1, nil, nil}, {9, 2, {8, 1, nil, nil}, {10, 1, nil, nil}}}},
              {13, 3, {12, 1, nil, nil}, {14, 2, nil, {15, 1, nil, nil}}}}
  end

  test "view" do
    tree =
      [{5, 50}, {1, 10}, {9, 90}, {1, 20}, {5, 40}, {6, 60}, {7, 70}, {2, 20}]
      |> Enum.into(PriceTree.new(fn {k1, _}, {k2, _} -> k1 < k2 end))

    assert PriceTree.view(tree) ==
             Enum.join(
               [
                 "            {5, 50}                ",
                 "       ┌───────┴───────┐           ",
                 "    {1, 20}         {6, 60}        ",
                 "   ┌───┴───┐       ┌───┴───────┐   ",
                 "{1, 10} {2, 20} {5, 40}     {9, 90}",
                 "                           ┌───┴┐  ",
                 "                        {7, 70}    "
               ],
               "\n"
             )
  end
end
