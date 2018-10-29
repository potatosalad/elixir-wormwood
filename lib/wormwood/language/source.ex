defmodule Wormwood.Language.Source do
  @moduledoc false
  defstruct body: nil,
            name: nil,
            line: nil

  @type t() :: %__MODULE__{
          body: nil | String.t(),
          name: nil | String.t(),
          line: nil | non_neg_integer()
        }
end
