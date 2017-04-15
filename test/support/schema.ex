defmodule Ecto.Paging.TestSchema do
  @moduledoc false
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

defmodule Ecto.Paging.UTCTestSchema do
  @moduledoc false
  use Ecto.Schema

  schema "apis_utc" do
    field :name, :string

    embeds_one :request, Request, primary_key: false do
      field :scheme, :string
      field :host, :string
      field :port, :integer
      field :path, :string
    end

    timestamps(type: :utc_datetime)
  end
end

defmodule Ecto.Paging.BinaryTestSchema do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "apis_binary" do
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

defmodule Ecto.Paging.StringTestSchema do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "apis_string" do
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
