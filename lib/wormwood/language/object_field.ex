defmodule Wormwood.Language.ObjectField do
  @moduledoc false

  defstruct name: nil,
            value: nil,
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          name: String.t(),
          value: Wormwood.Language.value_t(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.ObjectField do
  def encode(%@for{name: name, value: value}, depth) do
    [
      Wormwood.SDL.Utils.encode_name(name),
      ?:,
      ?\s,
      Wormwood.SDL.Encoder.encode(value, depth)
    ]
  end
end
