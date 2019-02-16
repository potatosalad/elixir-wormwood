defmodule Wormwood.Language.Argument do
  @moduledoc false

  defstruct name: nil,
            value: nil,
            loc: %{}

  @type t() :: %__MODULE__{
          name: String.t(),
          value: %{value: any()},
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.Argument do
  def encode(%@for{name: name, value: value}, opts) do
    [
      Wormwood.SDL.Utils.encode_name(name),
      ?:,
      ?\s,
      Wormwood.SDL.Encoder.encode(value, opts)
    ]
  end
end
