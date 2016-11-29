defmodule Ecto.PagingTest do
  use Ecto.Paging.ModelCase, async: true
  alias Ecto.Paging
  doctest Ecto.Paging

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
      {res, _paging} = Ecto.Paging.TestSchema
      |> Ecto.Paging.TestRepo.page(%Ecto.Paging{limit: 101})

      assert length(res) == 101
    end

    test "has default limit" do
      {res, _paging} = Ecto.Paging.TestSchema
      |> Ecto.Paging.TestRepo.page(%{})

      assert length(res) == 50
    end

    test "works with dropped limit" do
      {res, _paging} = Ecto.Paging.TestSchema
      |> Ecto.Paging.TestRepo.page(%{limit: nil})

      assert length(res) == 150
    end

    test "paginates forward with starting after" do
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

    test "paginates back with ending before" do
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
  end

  describe "paginator on binary id" do
    setup do
      insert_records_with_binary_id()
      :ok
    end

    test "limits results" do
      res1 = get_query_with_binary_id()
      |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 50})
      |> Ecto.Paging.TestRepo.all

      assert length(res1) == 50

      res2 = get_query_with_binary_id()
      |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 101})
      |> Ecto.Paging.TestRepo.all

      {res3, _paging} = get_query_with_binary_id()
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
      {res, _paging} = Ecto.Paging.BinaryTestSchema
      |> Ecto.Paging.TestRepo.page(%Ecto.Paging{limit: 101})

      assert length(res) == 101
    end

    test "has default limit" do
      {res, _paging} = Ecto.Paging.BinaryTestSchema
      |> Ecto.Paging.TestRepo.page(%{})

      assert length(res) == 50
    end

    test "works with dropped limit" do
      {res, _paging} = Ecto.Paging.BinaryTestSchema
      |> Ecto.Paging.TestRepo.page(%{limit: nil})

      assert length(res) == 150
    end

    test "paginates forward with starting after" do
      res1 = get_query_with_binary_id()
      |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
      |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      res2 = get_query_with_binary_id()
      |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{starting_after: Enum.at(res1, 49).id}})
      |> Ecto.Paging.TestRepo.all

      {res3, paging} = get_query_with_binary_id()
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

    test "paginates back with ending before" do
      res1 = get_query_with_binary_id()
      |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
      |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      res2 = get_query_with_binary_id()
      |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})
      |> Ecto.Paging.TestRepo.all

      {res3, paging} = get_query_with_binary_id()
      |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})

      assert res2 == res3

      assert length(res2) == 50

      # Second query should be subset of first one
      # TODO
      # assert 0 == 0..49
      # |> Enum.filter(fn index ->
      #   IO.inspect {Enum.at(res1, index + 99).id, Enum.at(res2, index).id}
      #   IO.inspect {Enum.at(res1, index + 99).inserted_at, Enum.at(res2, index).inserted_at}
      #   IO.inspect "======"
      #   Enum.at(res1, index + 99).id != Enum.at(res2, index).id
      # end)
      # |> length

      assert List.first(res2).id == paging.cursors.ending_before
      assert paging.has_more
    end
  end

  describe "paginator on string id" do
    setup do
      insert_records_with_string_id()
      :ok
    end

    test "limits results" do
      res1 = get_query_with_string_id()
      |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 50})
      |> Ecto.Paging.TestRepo.all

      assert length(res1) == 50

      res2 = get_query_with_string_id()
      |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 101})
      |> Ecto.Paging.TestRepo.all

      {res3, _paging} = get_query_with_string_id()
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
      {res, _paging} = Ecto.Paging.StringTestSchema
      |> Ecto.Paging.TestRepo.page(%Ecto.Paging{limit: 101})

      assert length(res) == 101
    end

    test "has default limit" do
      {res, _paging} = Ecto.Paging.StringTestSchema
      |> Ecto.Paging.TestRepo.page(%{})

      assert length(res) == 50
    end

    test "works with dropped limit" do
      {res, _paging} = Ecto.Paging.StringTestSchema
      |> Ecto.Paging.TestRepo.page(%{limit: nil})

      assert length(res) == 150
    end

    test "paginates forward with starting after" do
      res1 = get_query_with_string_id()
      |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
      |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      res2 = get_query_with_string_id()
      |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{starting_after: Enum.at(res1, 49).id}})
      |> Ecto.Paging.TestRepo.all

      {res3, paging} = get_query_with_string_id()
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

    test "paginates back with ending before" do
      res1 = get_query_with_string_id()
      |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
      |> Ecto.Paging.TestRepo.all

      assert length(res1) == 150

      res2 = get_query_with_string_id()
      |> Ecto.Paging.TestRepo.paginate(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})
      |> Ecto.Paging.TestRepo.all

      {res3, paging} = get_query_with_string_id()
      |> Ecto.Paging.TestRepo.page(%{limit: 50, cursors: %{ending_before: List.last(res1).id}})

      assert res2 == res3

      assert length(res2) == 50

      assert List.first(res2).id == paging.cursors.ending_before
      assert paging.has_more
    end
  end

  describe "Default ordering" do
    setup do
      logs_attrs = [
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

      logs = Enum.map(logs_attrs, fn item ->
        %Ecto.Paging.StringTestSchema{id: item.id}
        |> Ecto.Paging.TestRepo.insert!()
      end)

      {:ok, %{logs: logs}}
    end

    test "starting_after:2 + limit:5", %{logs: logs} do
      id = Enum.at(logs, 2).id

      expected_records =
        logs
        |> Enum.slice(3, 5)
        |> Enum.map(&Map.get(&1, :id))

      actual_records =
        Ecto.Paging.StringTestSchema
        |> Ecto.Paging.TestRepo.paginate(%{limit: 5, cursors: %{starting_after: id}})
        |> Ecto.Paging.TestRepo.all()
        |> Enum.map(&Map.get(&1, :id))

      assert expected_records == actual_records
    end
  end

  defp get_query do
    from p in Ecto.Paging.TestSchema
  end

  defp insert_records do
    for _ <- 1..150, do: Ecto.Paging.TestRepo.insert(%Ecto.Paging.TestSchema{name: "abc"})
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
