defmodule Ecto.PagingTest do
  use Ecto.Paging.ModelCase
  alias Ecto.Paging
  doctest Ecto.Paging

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

  test "pagination" do
    insert_records()
    query = from p in Ecto.Paging.Schema

    query = query
    |> Paging.paginate(%Ecto.Paging{limit: 50})

    prev = Ecto.Paging.Repo.all(query)
    |> Enum.map(fn record -> record.id end)
    |> IO.inspect

    query = query
    |> Paging.paginate(%Ecto.Paging{limit: 50, cursors: %Ecto.Paging.Cursors{starting_after: List.last(prev)}})

    Ecto.Paging.Repo.all(query)
    |> Enum.map(fn record -> record.id end)
    |> IO.inspect
  end

  def insert_records do
    for _ <- 1..150, do: Ecto.Paging.Repo.insert(%Ecto.Paging.Schema{name: "abc"})
  end
end
