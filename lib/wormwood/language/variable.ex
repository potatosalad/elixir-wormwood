defmodule Wormwood.Language.Variable do
  @moduledoc false

  defstruct name: nil,
            loc: %{line: nil}

  @type t() :: %__MODULE__{
          name: String.t(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.Variable do
  def encode(%@for{name: name}, _opts) when is_binary(name) do
    [?$, name]
  end
end
