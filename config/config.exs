use Mix.Config

config :ecto_paging, Ecto.Paging.TestRepo,
  adapter: Ecto.Adapters.Postgres,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "ecto_paging_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :ecto_paging, ecto_repos: [Ecto.Paging.TestRepo]

config :logger, level: :debug
config :ex_unit, capture_log: true
