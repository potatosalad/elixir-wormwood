defmodule Wormwood.Language.FragmentSpread do
  @moduledoc false

  defstruct name: nil,
            directives: [],
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          name: String.t(),
          directives: [Wormwood.Language.Directive.t()]
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.FragmentSpread do
  def encode(%@for{name: name, directives: directives}, opts = %{depth: depth}) do
    indent = :binary.copy("  ", depth)

    [
      indent,
      ?.,
      ?.,
      ?.,
      Wormwood.SDL.Utils.encode_name(name),
      Wormwood.SDL.Utils.encode_directives(directives, opts),
      ?\n
    ]
  end
end
