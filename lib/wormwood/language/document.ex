defmodule Wormwood.Language.Document do
  @moduledoc false

  defstruct definitions: [],
            loc: %{line: nil},
            source: nil

  @typedoc false
  @type t() :: %__MODULE__{
          definitions: [Wormwood.Traversal.Node.t()],
          loc: Wormwood.Language.loc_t(),
          source: nil | Wormwood.Language.Source.t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.Document do
  def encode(%@for{definitions: definitions = [_ | _]}, opts) do
    [head | tail] = Wormwood.SDL.Encoder.encode(definitions, opts)

    tail =
      for encoded <- tail, into: [] do
        [?\n, encoded]
      end

    [head | tail]
  end
end
