defmodule Wormwood.Language.NullValue do
  @moduledoc false

  defstruct [
    :loc
  ]

  @type t() :: %__MODULE__{
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.NullValue do
  def encode(%@for{}, _opts) do
    OJSON.encode!(nil)
  end
end
