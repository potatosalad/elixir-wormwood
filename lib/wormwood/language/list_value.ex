defmodule Wormwood.Language.ListValue do
  @moduledoc false

  defstruct values: [],
            loc: nil

  @type t() :: %__MODULE__{
          values: [Wormwood.Language.value_t()],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.ListValue do
  def encode(%@for{values: values}, depth) do
    [[?,, ?\s | head] | tail] = Enum.map(values, &[?,, ?\s, Wormwood.SDL.Encoder.encode(&1, depth)])
    [?[, head, tail, ?]]
  end
end
