defmodule Wormwood.Language.FloatValue do
  @moduledoc false

  defstruct [
    :value,
    :loc
  ]

  @type t() :: %__MODULE__{
          value: float(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.FloatValue do
  def encode(%@for{value: value}, _depth) do
    OJSON.encode!(value)
  end
end
