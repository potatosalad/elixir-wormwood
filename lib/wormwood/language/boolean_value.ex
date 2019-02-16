defmodule Wormwood.Language.BooleanValue do
  @moduledoc false

  defstruct [
    :value,
    :loc
  ]

  @type t() :: %__MODULE__{
          value: boolean(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.BooleanValue do
  def encode(%@for{value: value}, _opts) do
    OJSON.encode!(value)
  end
end
