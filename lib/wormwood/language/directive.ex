defmodule Wormwood.Language.Directive do
  @moduledoc false

  defstruct name: nil,
            arguments: [],
            loc: nil

  @type t() :: %__MODULE__{
          name: String.t(),
          arguments: [Wormwood.Language.Argument.t()],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.Directive do
  def encode(%@for{name: name, arguments: arguments}, depth) do
    [
      ?@,
      Wormwood.SDL.Utils.encode_name(name),
      Wormwood.SDL.Utils.encode_arguments(arguments, depth)
    ]
  end
end
