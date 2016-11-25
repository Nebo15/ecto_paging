defmodule Gateway.DB.Repo.Migrations.AddApisTable do
  use Ecto.Migration

  def change do
    create table(:apis) do
      add :name, :string
      add :request, :map

      timestamps()
    end

    create table(:apis_binary, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :request, :map

      timestamps()
    end

    create table(:apis_string, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string
      add :request, :map

      timestamps()
    end
  end
end
