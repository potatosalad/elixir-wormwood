defmodule Wormwood.Language.ScalarTypeDefinition do
  @moduledoc false

  defstruct name: nil,
            description: nil,
            directives: [],
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          name: String.t(),
          description: nil | String.t(),
          directives: [Wormwood.Language.Directive.t()],
          loc: Wormwood.Language.t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.ScalarTypeDefinition do
  def encode(%@for{description: description, name: name, directives: directives}, depth) do
    {header, depth} = Wormwood.SDL.Utils.maybe_extend(description, "scalar ", depth)

    [
      header,
      Wormwood.SDL.Utils.encode_name(name),
      Wormwood.SDL.Utils.encode_directives(directives, depth),
      ?\n
    ]
  end
end
