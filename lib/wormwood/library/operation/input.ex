defmodule Wormwood.Library.Operation.Input do
  @doc false
  def coerce!(
        %Wormwood.Library.Operation{
          library_module: library_module,
          document: %{
            definitions: [
              _operation_definition = %Wormwood.Language.OperationDefinition{variable_definitions: variable_definitions} | _
            ]
          }
        },
        input
      )
      when is_map(input) do
    if Code.ensure_loaded?(library_module) and function_exported?(library_module, :__wormwood_type__, 1) do
      maybe_coerce_variable_definitions!(library_module, variable_definitions, input)
    else
      raise("bad library")
    end
  end

  @doc false
  def maybe_coerce_variable_definitions!(library_module, variable_definitions, input) when is_map(input) do
    case variable_definitions do
      _ when is_nil(variable_definitions) or variable_definitions === [] ->
        if map_size(input) === 0 do
          input
        else
          raise("no variables defined")
        end

      [_ | _] ->
        coerce_variable_definitions!(library_module, variable_definitions, input)
    end
  end

  @doc false
  def coerce_variable_definitions!(library_module, variable_definitions = [_ | _], input) when is_map(input) do
    {possibly_invalid_input, valid_input} =
      Enum.reduce(variable_definitions, {input, Map.new()}, fn
        %Wormwood.Language.VariableDefinition{variable: %Wormwood.Language.Variable{name: name}, type: type_reference},
        {prev_input, next_input} ->
          case :maps.take(name, prev_input) do
            {raw_value, prev_input} ->
              coerced_value = coerce_type!(library_module, type_reference, raw_value)
              next_input = Map.put(next_input, name, coerced_value)
              {prev_input, next_input}

            :error ->
              if type_non_null?(type_reference) do
                raise("this is non-null: #{inspect(type_reference)}")
              else
                {prev_input, next_input}
              end
          end
      end)

    if map_size(possibly_invalid_input) === 0 do
      valid_input
    else
      raise("invalid input: #{inspect(possibly_invalid_input)}")
    end
  end

  @doc false
  def coerce_type!(library_module, %Wormwood.Language.ListType{type: next_type}, value) do
    case value do
      nil ->
        nil

      [] ->
        []

      [_ | _] ->
        Enum.map(value, &coerce_type!(library_module, next_type, &1))
    end
  end

  def coerce_type!(library_module, %Wormwood.Language.NonNullType{type: next_type}, value) do
    if not is_nil(value) do
      coerce_type!(library_module, next_type, value)
    else
      raise("must be non-null")
    end
  end

  def coerce_type!(library_module, %Wormwood.Language.NamedType{name: name}, value) do
    type = fetch_type_reference!(library_module, name)
    coerce_type!(library_module, type, value)
  end

  def coerce_type!(library_module, type, value) do
    if is_nil(value) do
      nil
    else
      case type do
        %Wormwood.Language.EnumTypeDefinition{} when is_binary(value) ->
          coerce_enum_type!(library_module, type, value)

        %Wormwood.Language.InputObjectTypeDefinition{} when is_map(value) ->
          coerce_input_object_type!(library_module, type, value)

        %Wormwood.Language.ScalarTypeDefinition{name: "Boolean"} when is_boolean(value) ->
          value

        %Wormwood.Language.ScalarTypeDefinition{name: "Float"} when is_float(value) ->
          value

        %Wormwood.Language.ScalarTypeDefinition{name: "ID"} when is_binary(value) or is_integer(value) ->
          value

        %Wormwood.Language.ScalarTypeDefinition{name: "Int"} when is_integer(value) ->
          value

        %Wormwood.Language.ScalarTypeDefinition{name: "String"} when is_binary(value) ->
          value

        %Wormwood.Language.ScalarTypeDefinition{name: name} ->
          if function_exported?(library_module, :coerce_scalar_input, 2) do
            case library_module.coerce_scalar_input(name, value) do
              {:ok, value} when is_binary(value) ->
                value
            end
          else
            raise("unable to coerce scalar of #{inspect(name)} type")
          end
      end
    end
  end

  @doc false
  def coerce_enum_type!(_library_module, %Wormwood.Language.EnumTypeDefinition{values: values = [_ | _]}, value)
      when is_binary(value) do
    is_enum_value? =
      Enum.any?(values, fn %Wormwood.Language.EnumValueDefinition{value: other} ->
        other === value
      end)

    if is_enum_value? do
      value
    else
      raise("invalid enum value")
    end
  end

  @doc false
  def coerce_input_object_type!(library_module, %Wormwood.Language.InputObjectTypeDefinition{fields: fields = [_ | _]}, input)
      when is_map(input) do
    {possibly_invalid_input, valid_input} =
      Enum.reduce(fields, {input, Map.new()}, fn
        %Wormwood.Language.InputValueDefinition{name: name, type: type_reference}, {prev_input, next_input} ->
          case :maps.take(name, prev_input) do
            {raw_value, prev_input} ->
              coerced_value = coerce_type!(library_module, type_reference, raw_value)
              next_input = Map.put(next_input, name, coerced_value)
              {prev_input, next_input}

            :error ->
              if type_non_null?(type_reference) do
                raise("this is non-null: #{inspect(type_reference)}")
              else
                {prev_input, next_input}
              end
          end
      end)

    if map_size(possibly_invalid_input) === 0 do
      valid_input
    else
      raise("invalid input: #{inspect(possibly_invalid_input)}")
    end
  end

  @doc false
  defp type_non_null?(%Wormwood.Language.NonNullType{}), do: true
  defp type_non_null?(%{__struct__: _}), do: false

  @doc false
  def fetch_type_reference!(library_module, name) do
    case library_module.__wormwood_type__(name) do
      type = %{__struct__: _} ->
        type

      nil ->
        raise("bad type: #{inspect(name)}")
    end
  end
end
