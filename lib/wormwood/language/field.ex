defmodule Wormwood.Language.Field do
  @moduledoc false

  defstruct alias: nil,
            name: nil,
            arguments: [],
            directives: [],
            selection_set: nil,
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          alias: nil | String.t(),
          name: String.t(),
          arguments: [Wormwood.Language.Argument.t()],
          directives: [Wormwood.Language.Directive.t()],
          selection_set: Wormwood.Language.SelectionSet.t(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.Field do
  def encode(
        %@for{alias: field_alias, name: name, arguments: arguments, directives: directives, selection_set: selection_set},
        depth
      ) do
    indent = :binary.copy("  ", depth)

    [
      indent,
      encode_alias(field_alias),
      Wormwood.SDL.Utils.encode_name(name),
      Wormwood.SDL.Utils.encode_arguments(arguments, depth),
      Wormwood.SDL.Utils.encode_directives(directives, depth),
      Wormwood.SDL.Utils.encode_selection_set(selection_set, depth),
      ?\n
    ]
  end

  @doc false
  defp encode_alias(nil) do
    []
  end

  defp encode_alias(field_alias) do
    [to_string(field_alias), ?:, ?\s]
  end
end
