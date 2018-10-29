defprotocol Wormwood.SDL.Encoder do
  def encode(term, depth)
end

defimpl Wormwood.SDL.Encoder, for: List do
  def encode([], _depth) do
    []
  end

  def encode(list = [_ | _], depth) do
    Enum.map(list, &Wormwood.SDL.Encoder.encode(&1, depth))
  end
end
