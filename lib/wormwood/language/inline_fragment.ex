defmodule Wormwood.Language.InlineFragment do
  @moduledoc false

  defstruct type_condition: nil,
            directives: [],
            selection_set: nil,
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          type_condition: nil | Wormwood.Language.NamedType.t(),
          directives: [Wormwood.Language.Directive.t()],
          selection_set: Wormwood.Language.SelectionSet.t(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.InlineFragment do
  def encode(%@for{type_condition: type_condition, directives: directives, selection_set: selection_set}, opts = %{depth: depth}) do
    indent = :binary.copy("  ", depth)

    [
      indent,
      ?.,
      ?.,
      ?.,
      Wormwood.SDL.Utils.encode_type_condition(type_condition, opts),
      Wormwood.SDL.Utils.encode_directives(directives, opts),
      Wormwood.SDL.Utils.encode_selection_set(selection_set, opts),
      ?\n
    ]
  end
end
