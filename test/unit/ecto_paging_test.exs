defmodule Ecto.PagingTest do
  use Ecto.Paging.ModelCase, async: false
  alias Ecto.Paging
  doctest Ecto.Paging

  test "works on empty list" do
    res = get_query()
    |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 50})
    |> Ecto.Paging.TestRepo.all

    assert res == []
  end

  test "works with corrupted cursors" do
    query =
      get_query()
      |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{
        limit: 50,
        cursors: %Ecto.Paging.Cursors{starting_after: 50, ending_before: 50}
      })

    assert Ecto.Paging.TestRepo.all(query) == []

    insert_records()

    assert Ecto.Paging.TestRepo.all(query) == []
  end

  test "explicitly defined ASC order works" do
    records = insert_records()
    {:ok, record} = List.last(records)
    {{:ok, penultimate_record}, _list} = List.pop_at(records, length(records) - 2)
    res1 =
      get_query()
      |> Ecto.Query.order_by(asc: :inserted_at)
      |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{ending_before: record.id}})
      |> Ecto.Paging.TestRepo.all
    assert penultimate_record.id == Enum.at(res1, 49).id
    # Ordering not influencing pagination
    assert length(res1) == 50
  end

  describe "converts from map" do
    test "with valid root struct" do
      assert %Ecto.Paging{limit: 50} = Paging.from_map(%Ecto.Paging{limit: 50})
    end

    test "with valid cursors struct" do
      assert %Ecto.Paging{cursors: %Ecto.Paging.Cursors{starting_after: 50}}
              = Paging.from_map(%Ecto.Paging{cursors: %Ecto.Paging.Cursors{starting_after: 50}})
    end

    test "with root values" do
      assert %Ecto.Paging{limit: 50} = Paging.from_map(%{limit: 50})
      assert %Ecto.Paging{has_more: true} = Paging.from_map(%{has_more: true})
    end

    test "with cursors" do
      assert %Ecto.Paging{cursors: %Ecto.Paging.Cursors{}} = Paging.from_map(%{})
      assert %Ecto.Paging{cursors: %Ecto.Paging.Cursors{starting_after: 50}}
              = Paging.from_map(%{cursors: %{starting_after: 50}})
      assert %Ecto.Paging{cursors: %Ecto.Paging.Cursors{ending_before: 50}}
              = Paging.from_map(%{cursors: %{ending_before: 50}})
    end

    test "with damaged cursors" do
      assert %Ecto.Paging{cursors: %Ecto.Paging.Cursors{starting_after: 3}}
              = Paging.from_map(%Ecto.Paging{cursors: %{starting_after: 3}})
    end
  end

  describe "converts to map" do
    test "drops struct" do
      assert %Ecto.Paging{cursors: %Ecto.Paging.Cursors{}}
      |> Paging.to_map()
      |> is_map()
    end

    test "keeps raw values" do
      assert %{limit: 50} = Paging.to_map(%Ecto.Paging{limit: 50})
      assert %{has_more: true} = Paging.to_map(%Ecto.Paging{has_more: true})
    end

    test "keeps cursors" do
      assert %{cursors: %{starting_after: 50}}
              = Paging.to_map(%Ecto.Paging{cursors: %Ecto.Paging.Cursors{starting_after: 50}})
      assert %{cursors: %{ending_before: 50}}
              = Paging.to_map(%Ecto.Paging{cursors: %Ecto.Paging.Cursors{ending_before: 50}})
    end
  end

  describe "paginator on integer id" do
    setup do
      insert_records()
      :ok
    end

    test "limits results" do
      res1 =
        get_query()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 50})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 50

      res2 =
        get_query()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 101})
        |> Ecto.Paging.TestRepo.all

      {res3, _paging} =
        get_query()
        |> Ecto.Paging.TestRepo.page(%Ecto.Paging{limit: 101})

      assert res2 == res3

      assert length(res2) == 101

      assert 0 ==
        0..49
        |> Enum.filter(fn index ->
          Enum.at(res1, index).id != Enum.at(res2, index).id
        end)
        |> length
    end

    test "works with schema" do
      {res, _paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.TestSchema, %Ecto.Paging{limit: 101})

      assert length(res) == 101
    end

    test "has default limit" do
      {res, _paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.TestSchema, %{})

      assert length(res) == 50
    end

    test "works with dropped limit" do
      {res, _paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.TestSchema, %{limit: nil})

      assert length(res) == 150
    end

    test "paginates forward with starting after" do
      res1 =
        get_query()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      starting_record = Enum.at(res1, 49)
      second_record = Enum.at(res1, 50)

      res2 =
        get_query()
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{starting_after: starting_record.id}})
        |> Ecto.Paging.TestRepo.all

      {res3, paging} =
        get_query()
        |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{starting_after: starting_record.id}})

      %Ecto.Paging{cursors: cursors} = paging
      assert cursors.ending_before == Enum.at(res1, 50).id
      assert cursors.starting_after == Enum.at(res1, 99).id

      assert res2 == res3
      assert second_record in res2
      refute starting_record in res2

      assert length(res2) == 50

      # Second query should be subset of first one
      assert 0 ==
        0..49
        |> Enum.filter(fn index ->
          Enum.at(res1, index + 50).id != Enum.at(res2, index).id
        end)
        |> length

      assert List.last(res2).id == paging.cursors.starting_after
      assert paging.has_more
    end

    test "ending_before is not nil" do
      {[head | _] = items, paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.TestSchema, %{limit: 150})
      assert 150 == Enum.count(items)
      assert %{cursors: %{ending_before: ending_before}, has_more: true} = paging
      assert head.id == ending_before
    end

    test "paginates forward with starting after with ordering" do
      res1 =
        get_query()
        |> Ecto.Query.order_by(asc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      starting_record = Enum.at(res1, 49)
      second_record = Enum.at(res1, 50)

      res2 =
        get_query()
        |> Ecto.Query.order_by(asc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{starting_after: starting_record.id}})
        |> Ecto.Paging.TestRepo.all

      {res3, paging} =
        get_query()
        |> Ecto.Query.order_by(asc: :inserted_at)
        |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{starting_after: starting_record.id}})

      %Ecto.Paging{cursors: cursors} = paging
      assert cursors.ending_before == Enum.at(res1, 50).id
      assert cursors.starting_after == Enum.at(res1, 99).id

      assert res2 == res3
      assert second_record in res2
      refute starting_record in res2

      assert length(res2) == 50

      # Second query should be subset of first one
      assert 0 ==
        0..49
        |> Enum.filter(fn index ->
          Enum.at(res1, index + 50).id != Enum.at(res2, index).id
        end)
        |> length

      assert List.last(res2).id == paging.cursors.starting_after
      assert paging.has_more
    end

    test "paginates back with ending before" do
      res1 =
        get_query()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      res2 =
        get_query()
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})
        |> Ecto.Paging.TestRepo.all

      {res3, paging} =
        get_query()
        |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})

      %Ecto.Paging{cursors: cursors} = paging
      assert cursors.ending_before == Enum.at(res1, 99).id
      assert cursors.starting_after == Enum.at(res1, 148).id

      assert res2 == res3

      assert length(res2) == 50

      {penultimate_record, _list} = List.pop_at(res1, length(res1) - 2)
      {start_record, _list} = List.pop_at(res1, length(res1) - 51)
      assert Enum.any?(res2, &(&1.id == penultimate_record.id))
      assert Enum.any?(res2, &(&1.id == start_record.id))
      refute List.last(res1) in res2

      # Second query should be subset of first one
      assert 0 ==
        0..49
        |> Enum.filter(fn index ->
          Enum.at(res1, index + 99).id != Enum.at(res2, index).id
        end)
        |> length

      assert List.first(res2).id == paging.cursors.ending_before
      assert paging.has_more
    end

    test "paginate back with ending before, but with order by DESC" do
      # Order by desc query and paginate from first elem
      res1 =
        get_query()
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%{limit: 5})
        |> Ecto.Paging.TestRepo.all

      # Ordering not influencing pagination
      assert length(res1) == 5

      res2 =
        get_query()
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%{limit: 5, cursors: %{ending_before: List.last(res1).id}})
        |> Ecto.Paging.TestRepo.all

      # %{ending_before} return inversed result properly
      assert length(res2) == 4
      refute List.last(res1) in res2
      {_, paging} = get_query()
      |> Ecto.Query.order_by(desc: :inserted_at)
      |> Ecto.Paging.TestRepo.page(%{limit: 5, cursors: %{ending_before: List.last(res1).id}})

      %Ecto.Paging{cursors: cursors} = paging
      assert cursors.ending_before == List.first(res1).id
      assert cursors.starting_after == Enum.at(res1, 3).id
    end
  end

  describe "paginator on integer id with UTC chronological fields" do
    setup do
      insert_records_with_utc_timestamps()
      :ok
    end

    test "limits results" do
      res1 =
        get_query_with_utc_timestamps()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 50})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 50

      res2 =
        get_query_with_utc_timestamps()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 101})
        |> Ecto.Paging.TestRepo.all

      {res3, _paging} =
        get_query_with_utc_timestamps()
        |> Ecto.Paging.TestRepo.page(%Ecto.Paging{limit: 101})

      assert res2 == res3

      assert length(res2) == 101

      assert 0 ==
        0..49
        |> Enum.filter(fn index ->
          Enum.at(res1, index).id != Enum.at(res2, index).id
        end)
        |> length
    end

    test "works with schema" do
      {res, _paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.UTCTestSchema, %Ecto.Paging{limit: 101})

      assert length(res) == 101
    end

    test "has default limit" do
      {res, _paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.UTCTestSchema, %{})

      assert length(res) == 50
    end

    test "works with dropped limit" do
      {res, _paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.UTCTestSchema, %{limit: nil})

      assert length(res) == 150
    end

    test "paginates forward with starting after" do
      res1 =
        get_query_with_utc_timestamps()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      res2 =
        get_query_with_utc_timestamps()
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{starting_after: Enum.at(res1, 49).id}})
        |> Ecto.Paging.TestRepo.all

      {res3, paging} =
        get_query_with_utc_timestamps()
        |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{starting_after: Enum.at(res1, 49).id}})

      %Ecto.Paging{cursors: cursors} = paging
      assert cursors.ending_before == Enum.at(res1, 50).id
      assert cursors.starting_after == Enum.at(res1, 99).id

      assert res2 == res3

      assert length(res2) == 50

      # Second query should be subset of first one
      assert 0 ==
        0..49
        |> Enum.filter(fn index ->
          Enum.at(res1, index + 50).id != Enum.at(res2, index).id
        end)
        |> length

      assert List.last(res2).id == paging.cursors.starting_after
      assert paging.has_more
    end

    test "paginates back with ending before" do
      res1 =
        get_query_with_utc_timestamps()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      res2 =
        get_query_with_utc_timestamps()
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})
        |> Ecto.Paging.TestRepo.all

      {res3, paging} =
        get_query_with_utc_timestamps()
        |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})

      %Ecto.Paging{cursors: cursors} = paging
      assert cursors.ending_before == Enum.at(res1, 99).id
      assert cursors.starting_after == Enum.at(res1, 148).id

      assert res2 == res3

      assert length(res2) == 50

      # Second query should be subset of first one
      assert 0 ==
        0..49
        |> Enum.filter(fn index ->
          Enum.at(res1, index + 99).id != Enum.at(res2, index).id
        end)
        |> length

      assert List.first(res2).id == paging.cursors.ending_before
      assert paging.has_more
    end

    test "paginate back with ending before, but with order by DESC" do
      # Order by desc query and paginate from first elem
      res1 =
        get_query_with_utc_timestamps()
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50})
        |> Ecto.Paging.TestRepo.all

      # Ordering not influencing pagination
      assert length(res1) == 50

      res2 =
        get_query_with_utc_timestamps()
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})
        |> Ecto.Paging.TestRepo.all

      # %{ending_before} return inversed result properly
      assert length(res2) == 49
      refute List.last(res1) in res2

      {_, paging} =
        get_query_with_utc_timestamps()
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})

      %Ecto.Paging{cursors: cursors} = paging
      assert cursors.ending_before == List.first(res1).id
      assert cursors.starting_after == Enum.at(res1, 48).id
    end
  end

  describe "paginator on binary id" do
    setup do
      insert_records_with_binary_id()
      :ok
    end

    test "limits results" do
      res1 =
        get_query_with_binary_id()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 50})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 50

      res2 =
        get_query_with_binary_id()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 101})
        |> Ecto.Paging.TestRepo.all

      {res3, _paging} =
        get_query_with_binary_id()
        |> Ecto.Paging.TestRepo.page(%Ecto.Paging{limit: 101})

      assert res2 == res3

      assert length(res2) == 101

      assert 0 ==
        0..49
        |>  Enum.filter(fn index ->
          Enum.at(res1, index).id != Enum.at(res2, index).id
        end)
        |> length
    end

    test "works with schema" do
      {res, _paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.BinaryTestSchema, %Ecto.Paging{limit: 101})

      assert length(res) == 101
    end

    test "has default limit" do
      {res, _paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.BinaryTestSchema, %{})
      assert length(res) == 50
    end

    test "works with dropped limit" do
      {res, _paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.BinaryTestSchema, %{limit: nil})

      assert length(res) == 150
    end

    test "paginates forward with starting after" do
      res1 =
        get_query_with_binary_id()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      res2 =
        get_query_with_binary_id()
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{starting_after: Enum.at(res1, 49).id}})
        |> Ecto.Paging.TestRepo.all

      {res3, paging} =
        get_query_with_binary_id()
        |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{starting_after: Enum.at(res1, 49).id}})

      %Ecto.Paging{cursors: cursors} = paging
      assert cursors.ending_before == Enum.at(res1, 50).id
      assert cursors.starting_after == Enum.at(res1, 99).id
      assert res2 == res3

      assert length(res2) == 50

      # Second query should be subset of first one
      assert 0 ==
        0..49
        |> Enum.filter(fn index ->
          Enum.at(res1, index + 50).id != Enum.at(res2, index).id
        end)
        |> length

      assert List.last(res2).id == paging.cursors.starting_after
      assert paging.has_more
    end

    test "paginates back with ending before" do
      res1 =
        get_query_with_binary_id()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      res2 =
        get_query_with_binary_id()
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})
        |> Ecto.Paging.TestRepo.all

      {penultimate_record, _list} = List.pop_at(res1, length(res1) - 2)
      {start_record, _list} = List.pop_at(res1, length(res1) - 51)

      assert Enum.any?(res2, &(&1.id == penultimate_record.id))
      assert Enum.any?(res2, &(&1.id == start_record.id))
      refute List.last(res1) in res2

      {res3, paging} =
        get_query_with_binary_id()
        |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})

      %Ecto.Paging{cursors: cursors} = paging
      assert cursors.ending_before == Enum.at(res1, 99).id
      assert cursors.starting_after == Enum.at(res1, 148).id

      assert res2 == res3

      assert length(res2) == 50

      assert 0 ==
        0..49
        |> Enum.filter(fn index ->
          Enum.at(res1, index + 99).id != Enum.at(res2, index).id
        end)
        |> length

      assert List.first(res2).id == paging.cursors.ending_before
      assert paging.has_more
    end

    test "paginate back with ending before, but with order by DESC" do
      # Order by desc query and paginate from first elem
      res1 =
        get_query_with_binary_id()
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%{limit: 150})
        |> Ecto.Paging.TestRepo.all

      # Ordering not influencing pagination
      assert length(res1) == 150

      res2 =
        get_query_with_binary_id()
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})
        |> Ecto.Paging.TestRepo.all

      penultimate_record = Enum.at(res1, 148)
      start_record = List.first(res1)

      assert Enum.any?(res2, &(&1.id == penultimate_record.id))
      refute start_record in res2
      refute List.last(res1) in res2

      # %{ending_before} return inversed result properly
      assert length(res2) == 50

      cursors = %Ecto.Paging.Cursors{starting_after: nil, ending_before: List.last(res1).id}
      page = %Ecto.Paging{limit: 50, cursors: cursors}

      query = get_query_with_binary_id()
      {res3, _page} =
        query
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.page(page)
      assert length(res3) == 50

      assert Enum.any?(res3, &(&1.id == penultimate_record.id))
      refute List.last(res1) in res3

    end
  end

  describe "paginator on string id" do
    setup do
      insert_records_with_string_id()
      :ok
    end

    test "limits results" do
      res1 =
        get_query_with_string_id()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 50})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 50

      res2 =
        get_query_with_string_id()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 101})
        |> Ecto.Paging.TestRepo.all

      {res3, _paging} =
        get_query_with_string_id()
        |> Ecto.Paging.TestRepo.page(%Ecto.Paging{limit: 101})

      assert res2 == res3

      assert length(res2) == 101

      assert 0 ==
        0..49
        |> Enum.filter(fn index ->
          Enum.at(res1, index).id != Enum.at(res2, index).id
        end)
        |> length
    end

    test "works with schema" do
      {res, _paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.StringTestSchema, %Ecto.Paging{limit: 101})

      assert length(res) == 101
    end

    test "has default limit" do
      {res, _paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.StringTestSchema, %{})

      assert length(res) == 50
    end

    test "works with dropped limit" do
      {res, _paging} = Ecto.Paging.TestRepo.page(Ecto.Paging.StringTestSchema, %{limit: nil})

      assert length(res) == 150
    end

    test "paginates forward with starting after" do
      res1 =
        get_query_with_string_id()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      res2 =
        get_query_with_string_id()
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{starting_after: Enum.at(res1, 49).id}})
        |> Ecto.Paging.TestRepo.all

      {res3, paging} =
        get_query_with_string_id()
        |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{starting_after: Enum.at(res1, 49).id}})

      %Ecto.Paging{cursors: cursors} = paging
      assert cursors.ending_before == Enum.at(res1, 50).id
      assert cursors.starting_after == Enum.at(res1, 99).id

      assert res2 == res3

      assert length(res2) == 50

      # Second query should be subset of first one
      assert 0 ==
        0..49
        |> Enum.filter(fn index ->
          Enum.at(res1, index + 50).id != Enum.at(res2, index).id
        end)
        |> length

      assert List.last(res2).id == paging.cursors.starting_after
      assert paging.has_more
    end

    test "paginates forward with starting after with ordering" do
      res1 =
        get_query_with_string_id()
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      res2 =
        get_query_with_string_id()
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{starting_after: Enum.at(res1, 49).id}})
        |> Ecto.Paging.TestRepo.all
      starting_record = Enum.at(res1, 50)
      last_record = Enum.at(res1, 99)

      assert starting_record in res2
      assert last_record in res2
      assert length(res2) == 50
    end

    test "paginates back with ending before" do
      res1 =
        get_query_with_string_id()
        |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      res2 =
        get_query_with_string_id()
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})
        |> Ecto.Paging.TestRepo.all

      {res3, paging} =
        get_query_with_string_id()
        |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})

      %Ecto.Paging{cursors: cursors} = paging
      assert cursors.ending_before == Enum.at(res1, 99).id
      assert cursors.starting_after == Enum.at(res1, 148).id

      assert res2 == res3

      assert length(res2) == 50

      penultimate_record = Enum.at(res1, 148)
      start_record = Enum.at(res1, 99)

      assert Enum.any?(res2, &(&1.id == penultimate_record.id))
      assert Enum.any?(res2, &(&1.id == start_record.id))

      assert List.first(res2).id == paging.cursors.ending_before
      assert paging.has_more
    end

     test "paginates back with ending before with ORDERING" do
      res1 =
        get_query_with_string_id()
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150
      penultimate_record_id = Enum.at(res1, 148).id

      res2 =
        get_query_with_string_id()
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})
        |> Ecto.Paging.TestRepo.all

      assert Enum.any?(res2, &(&1.id == penultimate_record_id))
    end
  end

  describe "Default ordering" do
    setup do
      records_attrs = [
        %{id: "2da21858-e1ae-4d8f-a87d-c3f94b4f433e"},
        %{id: "b36cc9c3-4214-41e3-b12e-03fc2e7f6fa1"},
        %{id: "77a3e1ec-bd4b-443e-bc2c-ca365cc7dc25"},
        %{id: "b7d63e4b-1364-4c6e-8e07-bee8eea8c21f"},
        %{id: "e595eadd-a000-43e5-910b-31fc293d910b"},
        %{id: "86106137-f4cd-483a-9a95-0b90601bf8ba"},
        %{id: "1d27cbab-6192-47ba-9d32-f928b99ed666"},
        %{id: "73a30d5c-42e6-4ba3-a969-cd01d82cdef1"},
        %{id: "a97338cb-0665-42bc-91cc-1de726626553"},
        %{id: "ff591a0e-8773-4b8e-9708-44a75be6f8c8"}
      ]

      records = Enum.map(records_attrs, fn item ->
        Ecto.Paging.TestRepo.insert!(%Ecto.Paging.StringTestSchema{id: item.id})
      end)

      {:ok, %{records: records}}
    end

    test "starting_after:2 + limit:5", %{records: records} do
      id = Enum.at(records, 2).id

      expected_records =
        records
        |> Enum.slice(3, 5)
        |> Enum.map(&Map.get(&1, :id))

      actual_records =
        Ecto.Paging.StringTestSchema
        |> Ecto.Paging.TestRepo.paginate(%{limit: 5, cursors: %{starting_after: id}})
        |> Ecto.Paging.TestRepo.all()
        |> Enum.map(&Map.get(&1, :id))

      actual_records_with_asc =
        Ecto.Paging.StringTestSchema
        |> Ecto.Query.order_by(asc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%{limit: 5, cursors: %{starting_after: id}})
        |> Ecto.Paging.TestRepo.all()
        |> Enum.map(&Map.get(&1, :id))

      assert expected_records == actual_records
      assert expected_records == actual_records_with_asc
    end

    test "ending_before:3", %{records: records} do
      id = Enum.at(records, 2).id

      expected_records =
        records
        |> Enum.slice(3, 5)
        |> Enum.reverse
        |> Enum.map(&Map.get(&1, :id))

      assert length(expected_records) == 5

      actual_records =
        Ecto.Paging.StringTestSchema
        |> Ecto.Query.order_by(desc: :inserted_at)
        |> Ecto.Paging.TestRepo.paginate(%{limit: 5, cursors: %{ending_before: id}})
        |> Ecto.Paging.TestRepo.all()
        |> Enum.map(&Map.get(&1, :id))

      assert expected_records == actual_records
    end
  end

  defp get_query do
    from p in Ecto.Paging.TestSchema
  end

  defp get_query_with_utc_timestamps do
    from p in Ecto.Paging.UTCTestSchema
  end

  defp insert_records do
    for _ <- 1..150, do: Ecto.Paging.TestRepo.insert(%Ecto.Paging.TestSchema{name: "abc"})
  end

  defp insert_records_with_utc_timestamps do
    for _ <- 1..150, do: Ecto.Paging.TestRepo.insert(%Ecto.Paging.UTCTestSchema{name: "abc"})
  end

  defp get_query_with_binary_id do
    from p in Ecto.Paging.BinaryTestSchema
  end

  defp insert_records_with_binary_id do
    for _ <- 1..150, do: Ecto.Paging.TestRepo.insert(%Ecto.Paging.BinaryTestSchema{name: "abc"})
  end

  defp get_query_with_string_id do
    from p in Ecto.Paging.StringTestSchema
  end

  defp insert_records_with_string_id do
    for _ <- 1..150, do: Ecto.Paging.TestRepo.insert(
      %Ecto.Paging.StringTestSchema{id: Ecto.UUID.generate(), name: "abc"}
    )
  end
end
