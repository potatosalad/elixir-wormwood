defmodule Wormwood.Language.FieldDefinition do
  @moduledoc false

  defstruct name: nil,
            description: nil,
            arguments: [],
            directives: [],
            type: nil,
            loc: %{line: nil}

  @type t :: %__MODULE__{
          name: String.t(),
          description: nil | String.t(),
          arguments: [Wormwood.Language.Argument.t()],
          directives: [Wormwood.Language.Directive.t()],
          type: Wormwood.Language.type_reference_t(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.FieldDefinition do
  def encode(
        %@for{description: description, name: name, arguments: arguments, type: type, directives: directives},
        opts = %{depth: depth}
      ) do
    indent = :binary.copy("  ", depth)

    [
      Wormwood.SDL.Utils.encode_description(description, opts),
      indent,
      Wormwood.SDL.Utils.encode_name(name),
      encode_input_arguments(arguments, opts),
      ?:,
      ?\s,
      Wormwood.SDL.Encoder.encode(type, opts),
      Wormwood.SDL.Utils.encode_directives(directives, opts),
      ?\n
    ]
  end

  @doc false
  defp encode_input_arguments(term, _depth) when is_nil(term) or term == [] do
    []
  end

  defp encode_input_arguments(list = [_ | _], opts = %{depth: depth}) do
    indent = :binary.copy("  ", depth)
    [?(, ?\n, Enum.map(list, &Wormwood.SDL.Encoder.encode(&1, %{opts | depth: depth + 1})), indent, ?)]
  end
end
