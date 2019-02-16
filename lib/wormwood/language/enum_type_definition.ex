defmodule Wormwood.Language.EnumTypeDefinition do
  @moduledoc false

  defstruct name: nil,
            description: nil,
            values: [],
            directives: [],
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          name: String.t(),
          description: nil | String.t(),
          values: [String.t()],
          directives: [Wormwood.Language.Directive.t()],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.EnumTypeDefinition do
  def encode(%@for{description: description, name: name, directives: directives, values: values}, opts) do
    {header, opts} = Wormwood.SDL.Utils.maybe_extend(description, "enum ", opts)

    [
      header,
      Wormwood.SDL.Utils.encode_name(name),
      Wormwood.SDL.Utils.encode_directives(directives, opts),
      Wormwood.SDL.Utils.encode_enum_values(values, opts),
      ?\n
    ]
  end
end
