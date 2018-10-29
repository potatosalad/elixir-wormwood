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

  # @doc "Extract a named operation definition from a document"
  # @spec get_operation(t, String.t()) :: nil | Wormwood.Language.OperationDefinition.t()
  # def get_operation(%{definitions: definitions}, name) do
  #   Enum.find(definitions, nil, fn
  #     %Wormwood.Language.OperationDefinition{name: ^name} ->
  #       true

  #     _ ->
  #       false
  #   end)
  # end

  # @doc false
  # @spec fragments_by_name(Wormwood.Language.Document.t()) :: %{
  #         String.t() => Wormwood.Language.Fragment.t()
  #       }
  # def fragments_by_name(%{definitions: definitions}) do
  #   definitions
  #   |> Enum.reduce(%{}, fn statement, memo ->
  #     case statement do
  #       %Wormwood.Language.Fragment{} ->
  #         memo |> Map.put(statement.name, statement)

  #       _ ->
  #         memo
  #     end
  #   end)
  # end
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.Document do
  def encode(%@for{definitions: definitions = [_ | _]}, depth) do
    Wormwood.SDL.Encoder.encode(definitions, depth)
  end
end
