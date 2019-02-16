defmodule Wormwood.Language.InputValueDefinition do
  @moduledoc false

  @enforce_keys [:name, :type]
  defstruct [
    :name,
    :type,
    description: nil,
    default_value: nil,
    directives: [],
    loc: %{line: nil}
  ]

  @type t() :: %__MODULE__{
          name: String.t(),
          description: nil | String.t(),
          type: Wormwood.Language.input_t(),
          default_value: Wormwood.Language.input_t(),
          directives: [Wormwood.Language.Directive.t()],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.InputValueDefinition do
  def encode(
        %@for{description: description, name: name, type: type, default_value: default_value, directives: directives},
        opts = %{depth: depth}
      ) do
    indent = :binary.copy("  ", depth)

    [
      Wormwood.SDL.Utils.encode_description(description, opts),
      indent,
      Wormwood.SDL.Utils.encode_name(name),
      ?:,
      ?\s,
      Wormwood.SDL.Encoder.encode(type, opts),
      Wormwood.SDL.Utils.encode_default_value(default_value, opts),
      Wormwood.SDL.Utils.encode_directives(directives, opts),
      ?\n
    ]
  end
end
