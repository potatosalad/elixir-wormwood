defmodule Wormwood.Language.StringValue do
  @moduledoc false

  defstruct [
    :value,
    :loc
  ]

  @type t() :: %__MODULE__{
          value: String.t(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.StringValue do
  def encode(%@for{value: value}, _depth) do
    OJSON.encode!(value)
  end
end
