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
