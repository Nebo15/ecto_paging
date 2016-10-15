defmodule Ecto.Paging.Schema do
  @moduledoc """
  API entity schema.
  """

  use Ecto.Schema

  import Ecto
  import Ecto.Changeset
  import Ecto.Query
  import Ecto.Paging.Repo

  schema "apis" do
    field :name, :string

    embeds_one :request, Request, primary_key: false do
      field :scheme, :string
      field :host, :string
      field :port, :integer
      field :path, :string
    end

    timestamps()
  end
end
