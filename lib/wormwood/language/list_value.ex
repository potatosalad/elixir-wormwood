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
  def encode(%@for{values: values}, opts) do
    [[?,, ?\s | head] | tail] = Enum.map(values, &[?,, ?\s, Wormwood.SDL.Encoder.encode(&1, opts)])
    [?[, head, tail, ?]]
  end
end
