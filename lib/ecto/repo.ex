defmodule Ecto.Pagging.Repo do
  defmacro __using__(_) do
    quote location: :keep do
      @conf [repo: __MODULE__, chronological_field: :inserted_at]
      def paginate(query, paging) do
        Ecto.Paging.paginate(query, paging, @conf)
      end
    end
  end
end
