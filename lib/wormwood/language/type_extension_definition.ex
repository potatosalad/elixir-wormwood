defmodule Wormwood.Language.TypeExtensionDefinition do
  @moduledoc false

  defstruct definition: nil,
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          definition: Wormwood.Language.SchemaDefinition.t() | Wormwood.Language.type_definition_t(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.TypeExtensionDefinition do
  def encode(%@for{definition: definition = %{__struct__: _}}, depth) do
    @protocol.encode(definition, {:extend, "extend ", depth})
  end
end
