defmodule Ecto.Pagging.Repo do
  @moduledoc """
  This module provides macro that injects `paginate/2` method into Ecto.Repo's.
  """
  defmacro __using__(_) do
    quote location: :keep do
      @conf [repo: __MODULE__, chronological_field: :inserted_at]

      @doc """
      Convert queriable to queryable with applied pagination rules from `paging`.
      """
      def paginate(queryable, paging) do
        Ecto.Paging.paginate(queryable, paging, @conf)
      end

      @doc """
      Fetches all entries from the data store matching the given query with applied Pagging.

      May raise `Ecto.QueryError` if query validation fails.

      ## Options

      See the "[Shared options](https://hexdocs.pm/ecto/Ecto.Repo.html#module-shared-options)"
      section at the `Ecto.Repo` module documentation.

      ## Example

          # Fetch 50 post titles
          query = from p in Post,
               select: p.title

          MyRepo.all(query, %Ecto.Paging{limit: 50})
      """
      @spec page(queryable :: Ecto.Query.t, paging :: Ecto.Paging.t, opts :: Keyword.t)
            :: {[Ecto.Schema.t], Ecto.Paging.t} | no_return
      def page(queryable, paging, opts \\ []) do
        res = queryable
        |> paginate(paging)
        |> __MODULE__.all(opts)

        case res do
          list when is_list(list) -> {list, Ecto.Paging.get_next_paging(list, paging)}
          err -> err
        end
      end
    end
  end
end
