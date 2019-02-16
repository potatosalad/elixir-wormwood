defmodule Wormwood.Language.NonNullType do
  @moduledoc false

  defstruct type: nil,
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          type: Wormwood.Language.type_reference_t(),
          loc: Wormwood.Language.t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.NonNullType do
  def encode(%@for{type: type}, opts) do
    [Wormwood.SDL.Encoder.encode(type, opts), ?!]
  end
end
