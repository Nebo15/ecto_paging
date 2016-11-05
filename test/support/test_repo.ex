defmodule Ecto.Paging.TestRepo do
  @moduledoc """
  Repo for Ecto database.

  More info: https://hexdocs.pm/ecto/Ecto.Repo.html
  """

  use Ecto.Repo, otp_app: :ecto_paging
  use Ecto.Pagging.Repo
end
