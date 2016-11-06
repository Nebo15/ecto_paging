defmodule Ecto.PagingTest do
  use Ecto.Paging.ModelCase
  alias Ecto.Paging
  doctest Ecto.Paging

  setup do
    insert_records()
    :ok
  end

  test "converts from map" do
    assert %Ecto.Paging{limit: 50} = Paging.from_map(%{limit: 50})
    assert %Ecto.Paging{has_more: true} = Paging.from_map(%{has_more: true})

    assert %Ecto.Paging{cursors: %Ecto.Paging.Cursors{}} = Paging.from_map(%{})
    assert %Ecto.Paging{cursors: %Ecto.Paging.Cursors{starting_after: 50}}
            = Paging.from_map(%{cursors: %{starting_after: 50}})
    assert %Ecto.Paging{cursors: %Ecto.Paging.Cursors{ending_before: 50}}
            = Paging.from_map(%{cursors: %{ending_before: 50}})
  end

 test "converts to map" do
    assert is_map(Paging.to_map(%Ecto.Paging{cursors: %Ecto.Paging.Cursors{}}))
    assert %{limit: 50} = Paging.to_map(%Ecto.Paging{limit: 50})
    assert %{has_more: true} = Paging.to_map(%Ecto.Paging{has_more: true})
    assert %{cursors: %{starting_after: 50}}
            = Paging.to_map(%Ecto.Paging{cursors: %Ecto.Paging.Cursors{starting_after: 50}})
    assert %{cursors: %{ending_before: 50}}
            = Paging.to_map(%Ecto.Paging{cursors: %Ecto.Paging.Cursors{ending_before: 50}})
  end

  test "limits results" do
    res1 = get_query()
    |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 50})
    |> Ecto.Paging.TestRepo.all

    assert length(res1) == 50

    res2 = get_query()
    |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 101})
    |> Ecto.Paging.TestRepo.all

    {res3, _paging} = get_query()
    |> Ecto.Paging.TestRepo.page(%Ecto.Paging{limit: 101})

    assert res2 == res3

    assert length(res2) == 101

    assert 0 == 0..49
    |> Enum.filter(fn index ->
      Enum.at(res1, index).id != Enum.at(res2, index).id
    end)
    |> length
  end

  test "works with schema" do
    {res, _paging} = Ecto.Paging.Schema
    |> Ecto.Paging.TestRepo.page(%Ecto.Paging{limit: 101})

    assert length(res) == 101
  end

  test "has default limit" do
    {res, _paging} = Ecto.Paging.Schema
    |> Ecto.Paging.TestRepo.page(%{})

    assert length(res) == 50
  end

  test "works with dropped limit" do
    {res, _paging} = Ecto.Paging.Schema
    |> Ecto.Paging.TestRepo.page(%{limit: nil})

    assert length(res) == 150
  end

  test "starting after" do
    res1 = get_query()
    |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
    |> Ecto.Paging.TestRepo.all

    assert length(res1) == 150

    res2 = get_query()
    |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{starting_after: Enum.at(res1, 49).id}})
    |> Ecto.Paging.TestRepo.all

    {res3, paging} = get_query()
    |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{starting_after: Enum.at(res1, 49).id}})

    assert res2 == res3

    assert length(res2) == 50

    # Second query should be subset of first one
    assert 0 == 0..49
    |> Enum.filter(fn index ->
      Enum.at(res1, index + 50).id != Enum.at(res2, index).id
    end)
    |> length

    assert List.last(res2).id == paging.cursors.starting_after
    assert paging.has_more
  end

  test "ending before" do
    res1 = get_query()
    |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
    |> Ecto.Paging.TestRepo.all

    assert length(res1) == 150

    res2 = get_query()
    |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})
    |> Ecto.Paging.TestRepo.all

    {res3, paging} = get_query()
    |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})

    assert res2 == res3

    assert length(res2) == 50

    # Second query should be subset of first one
    assert 0 == 0..49
    |> Enum.filter(fn index ->
      Enum.at(res1, index + 99).id != Enum.at(res2, index).id
    end)
    |> length

    assert List.first(res2).id == paging.cursors.ending_before
    assert paging.has_more
  end

  defp get_query do
    from p in Ecto.Paging.Schema
  end

  defp insert_records do
    for _ <- 1..150, do: Ecto.Paging.TestRepo.insert(%Ecto.Paging.Schema{name: "abc"})
  end
end
