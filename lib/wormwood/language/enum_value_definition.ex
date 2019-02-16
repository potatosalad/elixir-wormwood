defmodule Wormwood.Language.EnumValueDefinition do
  @moduledoc false

  @enforce_keys [:value]
  defstruct [
    :value,
    description: nil,
    directives: [],
    loc: %{line: nil, column: nil}
  ]

  @type t() :: %__MODULE__{
          value: String.t(),
          description: nil | String.t(),
          directives: [Wormwood.Language.Directive.t()],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.EnumValueDefinition do
  def encode(%@for{description: description, value: value, directives: directives}, opts = %{depth: depth}) do
    indent = :binary.copy("  ", depth)

    [
      Wormwood.SDL.Utils.encode_description(description, opts),
      indent,
      to_string(value),
      Wormwood.SDL.Utils.encode_directives(directives, opts),
      ?\n
    ]
  end
end
