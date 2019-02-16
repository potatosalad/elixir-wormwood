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
  def encode(%@for{description: description, directives: directives, fields: fields}, opts) do
    {header, opts} = Wormwood.SDL.Utils.maybe_extend(description, "schema", opts)

    [
      header,
      Wormwood.SDL.Utils.encode_directives(directives, opts),
      Wormwood.SDL.Utils.encode_field_definitions(fields, opts),
      ?\n
    ]
  end
end
