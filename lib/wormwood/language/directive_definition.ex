defmodule Wormwood.Language.DirectiveDefinition do
  @moduledoc false

  defstruct name: nil,
            description: nil,
            arguments: [],
            directives: [],
            locations: [],
            loc: %{line: nil}

  @type t :: %__MODULE__{
          name: String.t(),
          description: nil | String.t(),
          directives: [Wormwood.Language.Directive.t()],
          arguments: [Wormwood.Language.Argument.t()],
          locations: [String.t()],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.DirectiveDefinition do
  def encode(
        %@for{description: description, name: name, arguments: arguments, directives: directives, locations: locations},
        opts = %{depth: depth}
      ) do
    indent = :binary.copy("  ", depth)

    [
      Wormwood.SDL.Utils.encode_description(description, opts),
      indent,
      "directive ",
      ?@,
      Wormwood.SDL.Utils.encode_name(name),
      encode_input_arguments(arguments, opts),
      Wormwood.SDL.Utils.encode_directives(directives, opts),
      encode_locations(locations, opts),
      ?\n
    ]
  end

  @doc false
  defp encode_input_arguments(term, _opts) when is_nil(term) or term == [] do
    []
  end

  defp encode_input_arguments(list = [_ | _], opts = %{depth: depth}) do
    indent = :binary.copy("  ", depth)
    [?(, ?\n, Enum.map(list, &Wormwood.SDL.Encoder.encode(&1, %{opts | depth: depth + 1})), indent, ?)]
  end

  @doc false
  defp encode_locations(term, _opts) when is_nil(term) or term == [] do
    []
  end

  defp encode_locations(list = [_ | _], _opts) do
    [[?\s, ?|, ?\s | head] | tail] = Enum.map(list, &[?\s, ?|, ?\s, to_string(&1)])
    [?\s, ?o, ?n, ?\s, head | tail]
  end
end
