defmodule Wormwood.Language.OperationDefinition do
  @moduledoc false

  defstruct operation: nil,
            name: nil,
            variable_definitions: [],
            directives: [],
            selection_set: nil,
            loc: %{line: nil}

  @type t :: %__MODULE__{
          operation: :query | :mutation | :subscription,
          name: nil | String.t(),
          variable_definitions: [Wormwood.Language.VariableDefinition.t()],
          directives: [Wormwood.Language.Directive.t()],
          selection_set: Wormwood.Language.SelectionSet.t(),
          loc: Wormwood.Language.loc_t()
        }
end

defimpl Wormwood.SDL.Encoder, for: Wormwood.Language.OperationDefinition do
  def encode(
        %@for{
          operation: operation,
          name: name,
          variable_definitions: variable_definitions,
          directives: directives,
          selection_set: selection_set
        },
        depth
      ) do
    indent = :binary.copy("  ", depth)

    [
      indent,
      encode_operation(operation),
      Wormwood.SDL.Utils.encode_name(name),
      encode_variable_definitions(variable_definitions, depth),
      Wormwood.SDL.Utils.encode_directives(directives, depth),
      Wormwood.SDL.Utils.encode_selection_set(selection_set, depth),
      ?\n
    ]
  end

  @doc false
  defp encode_operation(nil) do
    []
  end

  defp encode_operation(operation) do
    [to_string(operation), ?\s]
  end

  @doc false
  defp encode_variable_definitions(term, _depth) when is_nil(term) or term == [] do
    []
  end

  defp encode_variable_definitions(list = [_ | _], depth) do
    [[?,, ?\s | head] | tail] = Enum.map(list, &[?,, ?\s, Wormwood.SDL.Encoder.encode(&1, depth)])
    [?(, head, tail, ?)]
  end
end
