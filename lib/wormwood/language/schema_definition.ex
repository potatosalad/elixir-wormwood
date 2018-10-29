defmodule Wormwood.Language.SchemaDefinition do
  @moduledoc false

  defstruct description: nil,
            directives: [],
            fields: [],
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          description: nil | String.t(),
          directives: [Wormwood.Language.Directive.t()],
          fields: [Wormwood.Language.FieldDefinition.t()],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.SchemaDefinition do
  def encode(%@for{description: description, directives: directives, fields: fields}, depth) do
    {header, depth} = Wormwood.SDL.Utils.maybe_extend(description, "schema", depth)

    [
      header,
      Wormwood.SDL.Utils.encode_directives(directives, depth),
      Wormwood.SDL.Utils.encode_field_definitions(fields, depth),
      ?\n
    ]
  end
end
