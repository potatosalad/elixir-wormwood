defmodule Wormwood.Language.IntValue do
  @moduledoc false

  defstruct [
    :value,
    :loc
  ]

  @type t() :: %__MODULE__{
          value: integer(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.IntValue do
  def encode(%@for{value: value}, _depth) do
    OJSON.encode!(value)
  end
end
