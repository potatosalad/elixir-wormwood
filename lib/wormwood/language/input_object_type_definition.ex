defmodule Wormwood.Language.InputObjectTypeDefinition do
  @moduledoc false

  defstruct name: nil,
            description: nil,
            fields: [],
            directives: [],
            loc: %{line: nil},
            errors: []

  @type t() :: %__MODULE__{
          name: String.t(),
          description: nil | String.t(),
          fields: [Wormwood.Language.InputValueDefinition.t()],
          directives: [Wormwood.Language.Directive.t()],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.InputObjectTypeDefinition do
  def encode(%@for{description: description, name: name, directives: directives, fields: fields}, depth) do
    {header, depth} = Wormwood.SDL.Utils.maybe_extend(description, "input ", depth)

    [
      header,
      Wormwood.SDL.Utils.encode_name(name),
      Wormwood.SDL.Utils.encode_directives(directives, depth),
      Wormwood.SDL.Utils.encode_field_definitions(fields, depth),
      ?\n
    ]
  end
end
