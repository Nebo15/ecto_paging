use Mix.Config

# Configuration for test environment


# Configure your database
config :ecto_paging, Ecto.Paging.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "ecto_paging_test"
