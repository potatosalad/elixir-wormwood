defmodule Wormwood.SDL.Encoder.Opts do
  @type t() :: %__MODULE__{
          depth: non_neg_integer()
        }
  defstruct depth: 0
end

defprotocol Wormwood.SDL.Encoder do
  @type t() :: term()
  @type opts() :: Wormwood.SDL.Encoder.Opts.t()

  def encode(term, opts)
end

defimpl Wormwood.SDL.Encoder, for: List do
  def encode([], _opts) do
    []
  end

  def encode(list = [_ | _], opts) do
    Enum.map(list, &Wormwood.SDL.Encoder.encode(&1, opts))
  end
end
