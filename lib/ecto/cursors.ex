defmodule Ecto.Paging.Cursors do
  @moduledoc false

  @doc """
  This is struct for `Ecto.Paging` that holds cursors.
  """
  defstruct starting_after: nil,
            ending_before: nil

  @type t :: %{starting_after: any, ending_before: any}
end
