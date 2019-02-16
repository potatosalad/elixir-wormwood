defmodule Wormwood.Language.SelectionSet do
  @moduledoc false

  defstruct selections: [],
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          selections: [
            Wormwood.Language.FragmentSpread.t() | Wormwood.Language.InlineFragment.t() | Wormwood.Language.Field.t()
          ],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.SelectionSet do
  def encode(%@for{selections: selections}, opts = %{depth: depth}) when is_list(selections) and length(selections) > 0 do
    indent = :binary.copy("  ", depth)
    [?{, ?\n, Enum.map(selections, &Wormwood.SDL.Encoder.encode(&1, %{opts | depth: depth + 1})), indent, ?}]
  end
end
