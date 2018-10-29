defmodule Wormwood.Language.InterfaceTypeDefinition do
  @moduledoc false

  defstruct name: nil,
            description: nil,
            fields: [],
            directives: [],
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          name: String.t(),
          description: nil | String.t(),
          fields: [Wormwood.Language.FieldDefinition.t()],
          directives: [Wormwood.Language.Directive.t()],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.InterfaceTypeDefinition do
  def encode(%@for{description: description, name: name, directives: directives, fields: fields}, depth) do
    {header, depth} = Wormwood.SDL.Utils.maybe_extend(description, "interface ", depth)

    [
      header,
      Wormwood.SDL.Utils.encode_name(name),
      Wormwood.SDL.Utils.encode_directives(directives, depth),
      Wormwood.SDL.Utils.encode_field_definitions(fields, depth),
      ?\n
    ]
  end
end
