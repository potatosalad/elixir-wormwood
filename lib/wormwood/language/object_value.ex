defmodule Wormwood.Language.ObjectValue do
  @moduledoc false

  defstruct fields: [],
            loc: nil

  @type t() :: %__MODULE__{
          fields: [Wormwood.Language.ObjectField.t()],
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.ObjectValue do
  def encode(%@for{fields: fields}, opts) do
    [[?,, ?\s | head] | tail] = Enum.map(fields, &[?,, ?\s, Wormwood.SDL.Encoder.encode(&1, opts)])
    [?{, head, tail, ?}]
  end
end
