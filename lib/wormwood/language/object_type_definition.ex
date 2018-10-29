defmodule Wormwood.Language.ObjectTypeDefinition do
  @moduledoc false

  defstruct name: nil,
            description: nil,
            directives: [],
            interfaces: [],
            fields: [],
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          name: String.t(),
          description: nil | String.t(),
          directives: [Wormwood.Language.Directive.t()],
          interfaces: [Wormwood.Language.NamedType.t()],
          fields: [Wormwood.Language.FieldDefinition.t()],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.ObjectTypeDefinition do
  def encode(%@for{description: description, name: name, directives: directives, interfaces: interfaces, fields: fields}, depth) do
    {header, depth} = Wormwood.SDL.Utils.maybe_extend(description, "type ", depth)

    [
      header,
      Wormwood.SDL.Utils.encode_name(name),
      Wormwood.SDL.Utils.encode_interfaces(interfaces, depth),
      Wormwood.SDL.Utils.encode_directives(directives, depth),
      Wormwood.SDL.Utils.encode_field_definitions(fields, depth),
      ?\n
    ]
  end
end
