defmodule Ecto.Paging.Schema do
  @moduledoc """
  API entity schema.
  """

  use Ecto.Schema

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
