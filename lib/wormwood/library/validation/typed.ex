defmodule Wormwood.Library.Validation.Typed do
  @moduledoc false

  defmodule TypedValueError do
    @moduledoc false
    defexception [:expected, :actual, :parent]

    import Wormwood.Library.Errors, only: [format_indent!: 2, format_loc!: 1, format_mod!: 1]

    def message(%__MODULE__{expected: expected, actual: actual}) do
      "#{format_mod!(expected)} expected, but found #{format_mod!(actual)} in #{format_loc!(actual)}"
    end

    def reason(%__MODULE__{expected: expected, parent: parent, actual: actual}) do
      expected_dump = dump_expected!(expected)
      parent_dump = :erlang.iolist_to_binary(Wormwood.SDL.encode(parent))
      actual_dump = "  " <> format_indent!(:erlang.iolist_to_binary(Wormwood.SDL.encode(actual)), 4)

      case expected do
        %Wormwood.Language.EnumTypeDefinition{values: values = [_ | _]} ->
          supported_values =
            values
            |> Enum.map(fn %{value: value} -> "  - #{format_indent!(value, 4)}" end)
            |> Enum.sort()
            |> Enum.join("\n")

          """
          Schema expected #{inspect(expected_dump)} of #{format_mod!(expected)} for typed value on #{inspect(parent_dump)} in #{
            format_loc!(parent)
          }

          Supported values:
          #{supported_values}

          Actual:
          #{actual_dump}

          See expected definition in #{format_loc!(expected)}
          """

        %Wormwood.Language.InputObjectTypeDefinition{fields: fields = [_ | _]} ->
          supported_values =
            fields
            |> Enum.map(fn %{name: name} -> "  - #{format_indent!(name, 4)}" end)
            |> Enum.sort()
            |> Enum.join("\n")

          """
          Schema expected #{inspect(expected_dump)} of #{format_mod!(expected)} for typed value on #{inspect(parent_dump)} in #{
            format_loc!(parent)
          }

          Supported fields:
          #{supported_values}

          Actual:
          #{actual_dump}

          See expected definition in #{format_loc!(expected)}
          """

        _ ->
          """
          Schema expected #{inspect(expected_dump)} of #{format_mod!(expected)} for typed value on #{inspect(parent_dump)} in #{
            format_loc!(parent)
          }

          Actual:
          #{actual_dump}

          See expected definition in #{format_loc!(expected)}
          """
      end
    end

    @doc false
    defp dump_expected!(type_reference = %{__struct__: module})
         when module in [
                Wormwood.Language.ListType,
                Wormwood.Language.NonNullType,
                Wormwood.Language.NamedType
              ] do
      :erlang.iolist_to_binary(Wormwood.SDL.encode(type_reference))
    end

    defp dump_expected!(%{name: name, loc: loc}) do
      dump_expected!(%Wormwood.Language.NamedType{name: name, loc: loc})
    end
  end

  defmodule UndefinedTypeReferenceError do
    @moduledoc false
    defexception [:node]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_mod!: 1]

    def message(%__MODULE__{node: node = %{name: name}}) do
      "Undefined type reference found for #{inspect(name)} of #{format_mod!(node)} in #{format_loc!(node)}"
    end
  end

  @doc false
  defmacrop raise_typed_value_error!(args) do
    quote do
      error = TypedValueError.exception(unquote(args))
      raise(Wormwood.Library.CompilationError, errors: [error], reason: TypedValueError.reason(error))
    end
  end

  @doc false
  def equal?(%Wormwood.Language.ListType{type: type1}, %Wormwood.Language.ListType{type: type2}) do
    equal?(type1, type2)
  end

  def equal?(%Wormwood.Language.NonNullType{type: type1}, %Wormwood.Language.NonNullType{type: type2}) do
    equal?(type1, type2)
  end

  def equal?(%Wormwood.Language.NamedType{name: name1}, %Wormwood.Language.NamedType{name: name2}) do
    name1 === name2
  end

  def equal?(_, _) do
    false
  end

  @doc """
  Non-strict left-hand side while ignoring right-hand side strictness.

  Equal:

    * `Int  == Int`
    * `Int! == Int!`
    * `Int! != Int`
    * `Int  != Int!`

  Equivalent:

    * `Int  ~~ Int`
    * `Int! ~~ Int!`
    * `Int! !~ Int`
    * `Int  ~~ Int!`

  """
  def equivalent?(%Wormwood.Language.ListType{type: type1}, %Wormwood.Language.ListType{type: type2}) do
    equivalent?(type1, type2)
  end

  def equivalent?(%Wormwood.Language.NonNullType{type: type1}, %Wormwood.Language.NonNullType{type: type2}) do
    equivalent?(type1, type2)
  end

  def equivalent?(%Wormwood.Language.NamedType{name: name1}, %Wormwood.Language.NamedType{name: name2}) do
    name1 === name2
  end

  def equivalent?(type1, %Wormwood.Language.NonNullType{type: type2}) do
    equivalent?(type1, type2)
  end

  def equivalent?(_, _) do
    false
  end

  @doc false
  def flatten_related_objects!(library, type) do
    interfaces_map = do_flatten_related_objects!(library, [type], Map.new())
    Map.values(interfaces_map)
  end

  @doc false
  defp do_flatten_related_objects!(library = %{types: types}, [head | tail], acc) do
    case head do
      type_reference = %Wormwood.Language.NamedType{} ->
        {:ok, type} = validate_type_reference!(library, type_reference)
        do_flatten_related_objects!(library, [type | tail], acc)

      interface = %Wormwood.Language.InterfaceTypeDefinition{name: interface_name} ->
        if Map.has_key?(acc, interface_name) do
          do_flatten_related_objects!(library, tail, acc)
        else
          related_objects =
            Enum.reduce(types, [], fn
              {_, object = %Wormwood.Language.ObjectTypeDefinition{name: _object_name, interfaces: interfaces}}, related_objects ->
                if Enum.any?(interfaces, fn %Wormwood.Language.NamedType{name: other_name} -> other_name === interface_name end) do
                  [object | related_objects]
                else
                  related_objects
                end

              _, related_objects ->
                related_objects
            end)

          acc = do_flatten_related_objects!(library, related_objects, Map.put(acc, interface_name, interface))
          do_flatten_related_objects!(library, tail, acc)
        end

      %Wormwood.Language.ObjectTypeDefinition{name: object_name, interfaces: interfaces} ->
        if Map.has_key?(acc, object_name) do
          do_flatten_related_objects!(library, tail, acc)
        else
          acc = do_flatten_related_objects!(library, interfaces, acc)
          do_flatten_related_objects!(library, tail, acc)
        end
    end
  end

  defp do_flatten_related_objects!(_library, [], acc) do
    acc
  end

  @doc false
  def resolve!(library, %Wormwood.Language.ListType{type: type_reference}) do
    resolve!(library, type_reference)
  end

  def resolve!(library, %Wormwood.Language.NonNullType{type: type_reference}) do
    resolve!(library, type_reference)
  end

  def resolve!(_library = %Wormwood.Library{types: types}, %Wormwood.Language.NamedType{name: name}) do
    Map.fetch!(types, name)
  end

  @doc false
  def validate_type_reference!(library, %Wormwood.Language.ListType{type: type_reference}) do
    validate_type_reference!(library, type_reference)
  end

  def validate_type_reference!(library, %Wormwood.Language.NonNullType{type: type_reference}) do
    validate_type_reference!(library, type_reference)
  end

  def validate_type_reference!(
        library = %Wormwood.Library{types: types},
        named_type = %Wormwood.Language.NamedType{name: name}
      ) do
    case Map.fetch(types, name) do
      {:ok, type} ->
        {:ok, type}

      :error ->
        errors = [UndefinedTypeReferenceError.exception(node: named_type)]

        raise(Wormwood.Library.CompilationError,
          errors: errors,
          reason: """
          All referenced types must be defined within a schema definition, but 1 undefined type reference was found.

          This module and/or its imported GraphQL is causing this error: #{inspect(library.module)}
          """
        )
    end
  end

  @doc false
  def validate_typed_value!(library, parent, type_reference, value) do
    case type_reference do
      %Wormwood.Language.ListType{type: next_type} ->
        case value do
          %Wormwood.Language.ListValue{values: []} ->
            :ok

          %Wormwood.Language.ListValue{values: values = [_ | _]} ->
            validate_typed_value_list!(library, parent, next_type, values)

          %Wormwood.Language.NullValue{} ->
            :ok

          %{__struct__: _} ->
            raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)
        end

      %Wormwood.Language.NonNullType{type: next_type} ->
        case value do
          %Wormwood.Language.NullValue{} ->
            raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)

          %{__struct__: _} ->
            validate_typed_value!(library, parent, next_type, value)
        end

      %Wormwood.Language.NamedType{} ->
        {:ok, type} = validate_type_reference!(library, type_reference)
        validate_typed_value!(library, parent, type, value)

      type ->
        case value do
          %Wormwood.Language.BooleanValue{} ->
            case type do
              %Wormwood.Language.ScalarTypeDefinition{name: type_name} when type_name in ["Boolean"] ->
                :ok

              %Wormwood.Language.ScalarTypeDefinition{} ->
                raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)

              %{__struct__: _} ->
                raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)
            end

          %Wormwood.Language.EnumValue{} ->
            case type do
              %Wormwood.Language.EnumTypeDefinition{} ->
                validate_typed_value_enum!(library, parent, type, value)

              %Wormwood.Language.ScalarTypeDefinition{} ->
                raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)

              %{__struct__: _} ->
                raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)
            end

          %Wormwood.Language.FloatValue{} ->
            case type do
              %Wormwood.Language.ScalarTypeDefinition{name: type_name} when type_name in ["Float"] ->
                :ok

              %Wormwood.Language.ScalarTypeDefinition{} ->
                raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)

              %{__struct__: _} ->
                raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)
            end

          %Wormwood.Language.IntValue{} ->
            case type do
              %Wormwood.Language.ScalarTypeDefinition{name: type_name} when type_name in ["ID", "Int"] ->
                :ok

              %Wormwood.Language.ScalarTypeDefinition{} ->
                raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)

              %{__struct__: _} ->
                raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)
            end

          %Wormwood.Language.ListValue{} ->
            raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)

          %Wormwood.Language.NullValue{} ->
            :ok

          %Wormwood.Language.ObjectValue{} ->
            case type do
              %Wormwood.Language.InputObjectTypeDefinition{} ->
                validate_typed_value_input_object!(library, parent, type, value)

              %Wormwood.Language.ScalarTypeDefinition{} ->
                raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)

              %{__struct__: _} ->
                raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)
            end

          %Wormwood.Language.StringValue{} ->
            case type do
              %Wormwood.Language.ScalarTypeDefinition{name: type_name} when type_name not in ["Boolean", "Float", "Int"] ->
                :ok

              %Wormwood.Language.ScalarTypeDefinition{} ->
                raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)

              %{__struct__: _} ->
                raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)
            end
        end
    end
  end

  @doc false
  def validate_typed_value_enum!(
        _library,
        parent,
        type_reference = %Wormwood.Language.EnumTypeDefinition{values: values = [_ | _]},
        value = %Wormwood.Language.EnumValue{value: enum_value}
      ) do
    has_enum_value = Enum.any?(values, fn %{value: enum_other} -> enum_value === enum_other end)

    if has_enum_value do
      :ok
    else
      raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)
    end
  end

  @doc false
  def validate_typed_value_input!(
        library,
        parent,
        %Wormwood.Language.InputValueDefinition{type: type_reference},
        %Wormwood.Language.ObjectField{value: value}
      ) do
    validate_typed_value!(library, parent, type_reference, value)
  end

  @doc false
  def validate_typed_value_input_object!(
        library,
        parent,
        type_reference = %Wormwood.Language.InputObjectTypeDefinition{fields: inpvals = [_ | _]},
        value = %Wormwood.Language.ObjectValue{fields: objvals}
      ) do
    inpvals =
      Enum.reduce(inpvals, Map.new(), fn
        inpval = %Wormwood.Language.InputValueDefinition{name: name}, acc ->
          Map.put(acc, name, inpval)
      end)

    objvals =
      case objvals do
        objvals when is_nil(objvals) or objvals === [] ->
          Map.new()

        objvals = [_ | _] ->
          Enum.reduce(objvals, Map.new(), fn
            objval = %Wormwood.Language.ObjectField{name: name}, acc ->
              Map.put(acc, name, objval)
          end)
      end

    unrecognized_objvals =
      Enum.reduce(inpvals, objvals, fn {inpval_name, inpval}, objvals ->
        case :maps.take(inpval_name, objvals) do
          {objval, new_objvals} ->
            :ok = validate_typed_value_input!(library, parent, inpval, objval)
            new_objvals

          :error ->
            case inpval do
              %{type: %Wormwood.Language.NonNullType{}} ->
                raise_typed_value_error!(expected: inpval, actual: value, parent: parent)

              %{__struct__: _} ->
                objvals
            end
        end
      end)

    if map_size(unrecognized_objvals) === 0 do
      :ok
    else
      raise_typed_value_error!(expected: type_reference, actual: value, parent: parent)
    end
  end

  @doc false
  def validate_typed_value_list!(_library, _parent, _type_reference, []) do
    :ok
  end

  def validate_typed_value_list!(library, parent, type_reference, [value | values]) do
    :ok = validate_typed_value!(library, parent, type_reference, value)
    validate_typed_value_list!(library, parent, type_reference, values)
  end
end
