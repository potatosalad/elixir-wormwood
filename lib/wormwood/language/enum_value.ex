defmodule Wormwood.Language.EnumValue do
  @moduledoc false

  defstruct value: nil,
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          value: any(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.EnumValue do
  def encode(%@for{value: value}, _opts) do
    to_string(value)
  end
end
