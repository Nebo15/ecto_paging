defmodule Ecto.Paging.Cursors do
  @moduledoc """
  This module defines nested struct with cursors for `Ecto.Paging`.
  """

  @doc """
  This is struct for `Ecto.Paging` that holds cursors.
  """
  defstruct starting_after: nil,
            ending_before: nil
end

defmodule Ecto.Paging do
  @moduledoc """
  This module provides a easy way to apply cursor-based pagination to your Ecto Queries.

  ## Usage:


  ## Limitations:
    * Right now it works only with schemas that have integer primary keys.
    (TODO: Investigate [SQL Cursors](https://www.postgresql.org/docs/9.2/static/plpgsql-cursors.html)).
    * It doesn't support of different order-by's, result can be ordered by PK only (TODO FIXME).
    * It doesn't construct `paginate` struct with `has_more` and `size` counts (TODO: add this helpers).
    * Ending before doesn't work without starting after and ignores limits
  """
  import Ecto.Query

  @doc """
  This struct defines pagination rules.
  It can be used in your response API.
  """
  defstruct limit: nil,
            cursors: %Ecto.Paging.Cursors{},
            has_more: nil,
            size: nil

  @doc """
  Convert map into `Ecto.Paging` struct.
  """
  def from_map(%{cursors: cursors} = paging) when is_map(cursors) do
    cursors = struct(Ecto.Paging.Cursors, cursors)

    struct(Ecto.Paging, paging)
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
  def paginate(%Ecto.Query{} = query, %Ecto.Paging{limit: limit, cursors: %Ecto.Paging.Cursors{} = cursors})
      when is_integer(limit) do
    query
    |> limit(^limit)
    |> filter_by_cursors(cursors)
  end

  def paginate(%Ecto.Query{} = query, paging) when is_map(paging) do
    paginate(query, Ecto.Paging.from_map(paging))
  end

  defp filter_by_cursors(query, %{starting_after: starting_after, ending_before: ending_before})
       when is_integer(starting_after) and is_integer(ending_before) do
    pk = get_primary_key(query)

    query
    |> where([c], field(c, ^pk) > ^starting_after)
    |> where([c], field(c, ^pk) < ^ending_before)
  end

  defp filter_by_cursors(query, %{starting_after: nil, ending_before: ending_before})
       when is_integer(ending_before) do
    pk = get_primary_key(query)

    query
    |> where([c], field(c, ^pk) < ^ending_before)
    |> reverse_orders(pk)
  end

  defp filter_by_cursors(query, %{starting_after: starting_after, ending_before: nil})
       when is_integer(starting_after) do
    pk = get_primary_key(query)

    query
    |> where([c], field(c, ^pk) > ^starting_after)
  end

  defp reverse_orders(%Ecto.Query{order_bys: order_bys} = query, pk)
       when is_list(order_bys) and length(order_bys) > 0 do
    IO.inspect "=== order ==="
    IO.inspect order_bys
    IO.inspect pk
    query
  end

  defp reverse_orders(%Ecto.Query{} = query, pk) do
    query
    |> order_by([c], asc: field(c, ^pk))
  end

  defp filter_by_cursors(query, _), do: query

  defp get_primary_key(%Ecto.Query{from: {_, model}}) do
    :primary_key
    |> model.__schema__
    |> List.first
  end
end
