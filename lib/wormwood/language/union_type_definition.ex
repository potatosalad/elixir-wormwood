defmodule Wormwood.Language.UnionTypeDefinition do
  @moduledoc false

  defstruct name: nil,
            description: nil,
            directives: [],
            types: [],
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          name: String.t(),
          description: nil | String.t(),
          directives: [Wormwood.Language.Directive.t()],
          types: [Wormwood.Language.NamedType.t()],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.UnionTypeDefinition do
  def encode(%@for{description: description, name: name, types: types, directives: directives}, opts) do
    {header, opts} = Wormwood.SDL.Utils.maybe_extend(description, "union ", opts)

    [
      header,
      Wormwood.SDL.Utils.encode_name(name),
      Wormwood.SDL.Utils.encode_directives(directives, opts),
      Wormwood.SDL.Utils.encode_union_types(types, opts),
      ?\n
    ]
  end
end
