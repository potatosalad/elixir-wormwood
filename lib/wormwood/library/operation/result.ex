defmodule Wormwood.Library.Operation.Result do
  defmodule State do
    @moduledoc false
    @enforce_keys [:library, :definitions, :type]
    defstruct [:library, :definitions, :type]

    def push(state = %__MODULE__{definitions: definitions}, definition) do
      definitions = [definition | definitions]
      %__MODULE__{state | definitions: definitions}
    end
  end

  @doc false
  def coerce!(
        %Wormwood.Library.Operation{
          library_module: library_module,
          document: %{definitions: [operation_definition = %Wormwood.Language.OperationDefinition{} | fragments]}
        },
        result
      )
      when is_map(result) do
    if Code.ensure_loaded?(library_module) and function_exported?(library_module, :__wormwood_library__, 0) do
      library = %Wormwood.Library{fragments: old_fragments} = library_module.__wormwood_library__()

      new_fragments =
        Enum.reduce(fragments, old_fragments, fn
          fragment = %Wormwood.Language.Fragment{name: name}, acc ->
            Map.put(acc, name, fragment)
        end)

      library = %{library | fragments: new_fragments}
      coerce_operation_definition!(library, operation_definition, result)
    else
      raise("bad library")
    end
  end

  @doc false
  def coerce_field!(
        library,
        field_definition = %Wormwood.Language.FieldDefinition{type: type},
        field = %Wormwood.Language.Field{},
        value
      ) do
    coerce_field_type!(library, field_definition, field, type, value)
  end

  @doc false
  def coerce_field_enum_type!(
        _library,
        _field_definition,
        _field,
        %Wormwood.Language.EnumTypeDefinition{values: values = [_ | _]},
        value
      )
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
  def coerce_field_interface_type!(
        state,
        _field_definition,
        _field = %Wormwood.Language.Field{selection_set: selection_set},
        definition = %Wormwood.Language.InterfaceTypeDefinition{},
        result
      )
      when is_map(result) do
    case Map.fetch(result, "__typename") do
      {:ok, type_name} ->
        type = fetch_named_type!(state, %Wormwood.Language.NamedType{name: type_name})

        {possibly_invalid_result, valid_result} =
          coerce_selection_set!(State.push(%State{state | type: type}, definition), selection_set, {result, Map.new()})

        if map_size(possibly_invalid_result) === 0 do
          valid_result
        else
          raise("invalid interface result: #{inspect(possibly_invalid_result)}")
        end

      :error ->
        raise("expected \"__typename\" to be there, but it wasn't :-(")
    end
  end

  @doc false
  def coerce_field_object_type!(
        state,
        _field_definition,
        _field = %Wormwood.Language.Field{selection_set: selection_set},
        definition = %Wormwood.Language.ObjectTypeDefinition{},
        result
      )
      when is_map(result) do
    case Map.fetch(result, "__typename") do
      {:ok, type_name} ->
        type = fetch_named_type!(state, %Wormwood.Language.NamedType{name: type_name})

        {possibly_invalid_result, valid_result} =
          coerce_selection_set!(State.push(%State{state | type: type}, definition), selection_set, {result, Map.new()})

        if map_size(possibly_invalid_result) === 0 do
          valid_result
        else
          raise("invalid interface result: #{inspect(possibly_invalid_result)}")
        end

      :error ->
        raise("expected \"__typename\" to be there, but it wasn't :-(")
    end
  end

  @doc false
  def coerce_field_type!(state, field_definition, field, %Wormwood.Language.ListType{type: next_type}, value) do
    case value do
      nil ->
        nil

      [] ->
        []

      [_ | _] ->
        Enum.map(value, &coerce_field_type!(state, field_definition, field, next_type, &1))
    end
  end

  def coerce_field_type!(state, field_definition, field, %Wormwood.Language.NonNullType{type: next_type}, value) do
    if not is_nil(value) do
      coerce_field_type!(state, field_definition, field, next_type, value)
    else
      raise("must be non-null")
    end
  end

  def coerce_field_type!(state, field_definition, field, named_type = %Wormwood.Language.NamedType{}, value) do
    type = fetch_named_type!(state, named_type)
    coerce_field_type!(state, field_definition, field, type, value)
  end

  def coerce_field_type!(state = %State{library: %{module: module}}, field_definition, field, type, value) do
    if is_nil(value) do
      nil
    else
      case type do
        %Wormwood.Language.EnumTypeDefinition{} when is_binary(value) ->
          coerce_field_enum_type!(state, field_definition, field, type, value)

        %Wormwood.Language.InterfaceTypeDefinition{} when is_map(value) ->
          coerce_field_interface_type!(state, field_definition, field, type, value)

        %Wormwood.Language.ObjectTypeDefinition{} when is_map(value) ->
          coerce_field_object_type!(state, field_definition, field, type, value)

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

        %Wormwood.Language.ScalarTypeDefinition{name: name} when is_binary(value) ->
          if function_exported?(module, :coerce_scalar_result, 2) do
            case module.coerce_scalar_result(name, value) do
              {:ok, value} ->
                value
            end
          else
            raise("unable to coerce scalar of #{inspect(name)} type")
          end
      end
    end
  end

  @doc false
  def coerce_fragment_spread!(state, fragment_spread = %Wormwood.Language.FragmentSpread{}, {prev_result, next_result}) do
    fragment =
      %Wormwood.Language.Fragment{type_condition: type_condition, selection_set: selection_set} =
      fetch_fragment!(state, fragment_spread)

    if has_fragment_type_condition?(state, fragment) do
      type_definition = fetch_named_type!(state, type_condition)
      coerce_selection_set!(State.push(state, type_definition), selection_set, {prev_result, next_result})
    else
      {prev_result, next_result}
    end
  end

  @doc false
  def coerce_inline_fragment!(
        state,
        inline_fragment = %Wormwood.Language.InlineFragment{type_condition: type_condition, selection_set: selection_set},
        {prev_result, next_result}
      ) do
    if has_fragment_type_condition?(state, inline_fragment) do
      type_definition = fetch_named_type!(state, type_condition)
      coerce_selection_set!(State.push(state, type_definition), selection_set, {prev_result, next_result})
    else
      {prev_result, next_result}
    end
  end

  @doc false
  def coerce_operation_definition!(
        library,
        operation_definition = %Wormwood.Language.OperationDefinition{selection_set: selection_set},
        result
      )
      when is_map(result) do
    schema_operation = fetch_schema_operation!(library, operation_definition)
    state = %State{library: library, definitions: [schema_operation], type: schema_operation}
    {possibly_invalid_result, valid_result} = coerce_selection_set!(state, selection_set, {result, Map.new()})

    if map_size(possibly_invalid_result) === 0 do
      valid_result
    else
      raise("invalid operation result: #{inspect(possibly_invalid_result)}")
    end
  end

  @doc false
  def coerce_selection_set!(
        state = %State{definitions: [%{__struct__: module, fields: field_definitions = [_ | _]} | _]},
        %Wormwood.Language.SelectionSet{selections: selections = [_ | _]},
        {prev_result, next_result}
      )
      when module in [
             Wormwood.Language.InterfaceTypeDefinition,
             Wormwood.Language.ObjectTypeDefinition
           ] do
    Enum.reduce(selections, {prev_result, next_result}, fn
      _field = %Wormwood.Language.Field{alias: field_alias, name: field_name = "__typename"}, {prev_result, next_result} ->
        field_key = if is_nil(field_alias), do: field_name, else: field_alias

        case :maps.take(field_key, prev_result) do
          {value, prev_result} when is_binary(value) ->
            :ok = validate_type!(state, value)
            next_result = Map.put(next_result, field_key, value)
            {prev_result, next_result}

          :error ->
            raise("expected #{inspect(field_key)} to be there, but it wasn't :-(")
        end

      field = %Wormwood.Language.Field{alias: field_alias, name: field_name}, {prev_result, next_result} ->
        field_key = if is_nil(field_alias), do: field_name, else: field_alias

        case :maps.take(field_key, prev_result) do
          {value, prev_result} ->
            field_definition =
              %Wormwood.Language.FieldDefinition{} = Enum.find(field_definitions, fn %{name: other} -> other === field_name end)

            value = coerce_field!(state, field_definition, field, value)
            next_result = Map.put(next_result, field_key, value)
            {prev_result, next_result}

          :error ->
            raise("expected #{inspect(field_key)} to be there, but it wasn't :-(")
        end

      fragment_spread = %Wormwood.Language.FragmentSpread{}, {prev_result, next_result} ->
        coerce_fragment_spread!(state, fragment_spread, {prev_result, next_result})

      inline_fragment = %Wormwood.Language.InlineFragment{}, {prev_result, next_result} ->
        coerce_inline_fragment!(state, inline_fragment, {prev_result, next_result})
    end)
  end

  @doc false
  def has_fragment_type_condition?(
        %State{type: %Wormwood.Language.ObjectTypeDefinition{name: object_type_name, interfaces: interfaces}},
        %{
          __struct__: module,
          type_condition: %Wormwood.Language.NamedType{name: fragment_type_name}
        }
      )
      when module in [Wormwood.Language.Fragment, Wormwood.Language.InlineFragment] do
    if object_type_name === fragment_type_name do
      true
    else
      Enum.any?(interfaces, fn
        %Wormwood.Language.NamedType{name: other_type_name} ->
          other_type_name === fragment_type_name
      end)
    end
  end

  @doc false
  def fetch_fragment!(%State{library: %Wormwood.Library{fragments: fragments}}, %Wormwood.Language.FragmentSpread{name: name}) do
    case fragments do
      %{^name => fragment = %Wormwood.Language.Fragment{}} ->
        fragment
    end
  end

  @doc false
  def fetch_named_type!(%State{library: %Wormwood.Library{types: types}}, %Wormwood.Language.NamedType{name: name}) do
    case types do
      %{^name => type} ->
        type
    end
  end

  @doc false
  def fetch_schema_operation!(%Wormwood.Library{module: module}, %Wormwood.Language.OperationDefinition{
        operation: operation
      }) do
    operation = to_string(operation)
    schema_operation = %Wormwood.Language.ObjectTypeDefinition{} = module.__wormwood_schema__(operation)
    schema_operation
  end

  @doc false
  def validate_type!(
        %State{type: %Wormwood.Language.ObjectTypeDefinition{name: object_type_name, interfaces: interfaces}},
        type_name
      ) do
    valid_type? =
      if object_type_name === type_name do
        true
      else
        Enum.any?(interfaces, fn
          %Wormwood.Language.NamedType{name: other_type_name} ->
            other_type_name === type_name
        end)
      end

    if valid_type? do
      :ok
    else
      raise("invalid type #{inspect(type_name)}, expected: #{inspect(object_type_name)}")
    end
  end
end
