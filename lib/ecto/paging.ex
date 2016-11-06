defmodule Ecto.Paging do
  @moduledoc """
  This module provides a easy way to apply cursor-based pagination to your Ecto Queries.

  ## Usage:
  1. Add macro to your repo

      defmodule MyRepo do
        use Ecto.Repo, otp_app: :my_app
        use Ecto.Pagging.Repo # This string adds `paginate/2` method.
      end

  2. Paginate!

      query = from p in Ecto.Paging.Schema

      query
      |> Ecto.Paging.TestRepo.paginate(%Ecto.Paging{limit: 150})
      |> Ecto.Paging.TestRepo.all

  ## Limitations:
    * Right now it works only with schemas that have `:inserted_at` field with auto-generated value.
    * You need to be careful with order-by's in your queries, since this feature is not tested yet.
    * It doesn't construct `paginate` struct with `has_more` and `size` counts (TODO: add this helpers).
    * When both `starting_after` and `ending_before` is set, only `starting_after` is used.
  """
  import Ecto.Query

  @type t :: %{limit: number, cursors: Ecto.Paging.Cursors.t, has_more: number, size: number}

  @doc """
  This struct defines pagination rules.
  It can be used in your response API.
  """
  defstruct limit: 50,
            cursors: %Ecto.Paging.Cursors{},
            has_more: nil,
            size: nil

  @doc """
  Convert map into `Ecto.Paging` struct.
  """
  def from_map(%{cursors: cursors} = paging) when is_map(cursors) do
    cursors = struct(Ecto.Paging.Cursors, cursors)

    Ecto.Paging
    |> struct(paging)
    |> Map.put(:cursors, cursors)
  end

  def from_map(paging) when is_map(paging) do
    struct(Ecto.Paging, paging)
  end

  @doc """
  Convert `Ecto.Paging` struct into map and drop all nil values and `cursors` property if it's empty.
  """
  def to_map(%Ecto.Paging{cursors: cursors} = paging) do
    cursors = cursors
    |> Map.delete(:__struct__)
    |> Enum.filter(fn {_, v} -> v end)
    |> Enum.into(%{})

    paging
    |> Map.delete(:__struct__)
    |> Map.put(:cursors, cursors)
    |> Enum.filter(fn {_, v} -> is_map(v) && v != %{} or not is_map(v) and v end)
    |> Enum.into(%{})
  end

  @doc """
  Apply pagination to a `Ecto.Query`.
  It can accept either `Ecto.Paging` struct or map that can be converted to it via `from_map/1`.
  """
  def paginate(%Ecto.Query{} = query,
               %Ecto.Paging{limit: limit, cursors: %Ecto.Paging.Cursors{} = cursors},
               [repo: _, chronological_field: _] = opts)
      when is_integer(limit) do
    pk = get_primary_key(query)

    query
    |> limit(^limit)
    |> filter_by_cursors(cursors, pk, opts)
  end

  def paginate(%Ecto.Query{} = query, paging, opts) when is_map(paging) do
    paginate(query, Ecto.Paging.from_map(paging), opts)
  end

  def paginate(queriable, paging, opts) when is_atom(queriable) do
    queriable
    |> Ecto.Queryable.to_query()
    |> paginate(paging, opts)
  end

  @doc """
  Build a `%Ecto.Paging{}` struct to fetch next page results based on previous `Ecto.Repo.all` result
  and previous paging struct.
  """
  def get_next_paging(query_result, %Ecto.Paging{limit: nil} = paging) do
    get_next_paging(query_result, %{paging | limit: length(query_result)})
  end

  def get_next_paging(query_result, %Ecto.Paging{limit: limit, cursors: cursors}) when is_list(query_result) do
    %Ecto.Paging{
      limit: limit,
      has_more: length(query_result) >= limit,
      cursors: get_next_cursors(query_result, cursors)
    }
  end

  def get_next_paging(query_result, paging) when is_map(paging) do
    get_next_paging(query_result, Ecto.Paging.from_map(paging))
  end

  defp get_next_cursors(query_result, %Ecto.Paging.Cursors{ending_before: ending_before})
      when not is_nil(ending_before) do
      %Ecto.Paging.Cursors{ending_before: List.first(query_result).id} # TODO: hardcoded `id` pk field
  end

  defp get_next_cursors(query_result, _) do
      %Ecto.Paging.Cursors{starting_after: List.last(query_result).id}
  end

  defp filter_by_cursors(%Ecto.Query{from: {table, _schema}} = query, %{starting_after: starting_after}, pk,
                        [repo: repo, chronological_field: chronological_field])
       when not is_nil(starting_after) do
    ts = extract_timestamp(repo, table, pk, starting_after, chronological_field)

    query
    |> where([c], field(c, ^chronological_field) > ^ts)
  end

  defp filter_by_cursors(%Ecto.Query{from: {table, _schema}} = query, %{ending_before: ending_before}, pk,
                        [repo: repo, chronological_field: chronological_field])
       when not is_nil(ending_before) do
    ts = extract_timestamp(repo, table, pk, ending_before, chronological_field)

    {rev_order, q} = query
    |> where([c], field(c, ^chronological_field) < ^ts)
    |> flip_orders(pk)

    from e in subquery(q), order_by: [{^rev_order, ^pk}]
  end

  defp filter_by_cursors(query, %{ending_before: nil, starting_after: nil}, _pk, _opts), do: query

  defp extract_timestamp(repo, table, pk, pk_value, chronological_field) do
    start_timestamp_native =
      repo.one from r in table,
        where: field(r, ^pk) == ^pk_value,
        select: field(r, ^chronological_field)

    {:ok, start_timestamp} = Ecto.DateTime.load(start_timestamp_native)

    start_timestamp
  end

  defp flip_orders(%Ecto.Query{order_bys: order_bys} = query, _pk)
       when is_list(order_bys) and length(order_bys) > 0 do
    {:desc, query}
  end

  defp flip_orders(%Ecto.Query{} = query, pk) do
    {:asc, query |> order_by([c], desc: field(c, ^pk))}
  end

  defp get_primary_key(%Ecto.Query{from: {_, model}}) do
    :primary_key
    |> model.__schema__
    |> List.first
  end
end
