defmodule Wormwood.Language.VariableDefinition do
  @moduledoc false

  defstruct variable: nil,
            type: nil,
            default_value: nil,
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          variable: Wormwood.Language.Variable.t(),
          type: Wormwood.Language.type_reference_t(),
          default_value: any(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.VariableDefinition do
  def encode(%@for{variable: variable = %{__struct__: _}, type: type = %{__struct__: _}, default_value: default_value}, depth) do
    [
      Wormwood.SDL.Encoder.encode(variable, depth),
      ?:,
      ?\s,
      Wormwood.SDL.Encoder.encode(type, depth),
      Wormwood.SDL.Utils.encode_default_value(default_value, depth)
    ]
  end
end
