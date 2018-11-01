defmodule Wormwood.Library.Validation.OperationTyped do
  @moduledoc false

  defmodule EmptySelectionSetError do
    @moduledoc false
    defexception [:definition, :selection]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_sdl!: 2]

    def message(%__MODULE__{definition: definition, selection: selection}) do
      """
      Object type selection error in #{format_loc!(selection)}

      Definition:

        #{format_sdl!(definition, 2)}

      Selection:

        #{format_sdl!(selection, 2)}

      Field selections MUST exist for InterfaceTypeDefintion or ObjectTypeDefinition.
      """
    end
  end

  defmodule FieldArgumentError do
    @moduledoc false
    defexception [:definition, :argument]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_sdl!: 2]

    def message(%__MODULE__{definition: definition, argument: argument}) do
      """
      Field argument error in #{format_loc!(argument)}

      Definition:

        #{format_sdl!(definition, 2)}

      Argument:

        #{format_sdl!(argument, 2)}

      See definition in #{format_loc!(definition)}
      """
    end
  end

  defmodule FieldSelectionError do
    @moduledoc false
    defexception [:definition, :selection]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_sdl!: 2]

    def message(%__MODULE__{definition: definition, selection: selection}) do
      """
      Field selection error in #{format_loc!(selection)}

      Definition:

        #{format_sdl!(definition, 2)}

      Selection:

        #{format_sdl!(selection, 2)}

      See definition in #{format_loc!(definition)}
      """
    end
  end

  defmodule InlineFragmentTypeError do
    @moduledoc false
    defexception [:definition, :selection]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_sdl!: 2]

    def message(%__MODULE__{definition: definition, selection: selection}) do
      """
      Inline fragment type error in #{format_loc!(selection)}

      Definition:

        #{format_sdl!(definition, 2)}

      Selection:

        #{format_sdl!(selection, 2)}

      Inline fragments may only be used on types of InterfaceTypeDefintion or ObjectTypeDefinition.
      """
    end
  end

  defmodule NonObjectSelectionError do
    @moduledoc false
    defexception [:definition, :selection]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_sdl!: 2]

    def message(%__MODULE__{definition: definition, selection: selection}) do
      """
      Non-object selection error in #{format_loc!(selection)}

      Definition:

        #{format_sdl!(definition, 2)}

      Selection:

        #{format_sdl!(selection, 2)}

      Field selections can only be done on InterfaceTypeDefintion or ObjectTypeDefinition.
      """
    end
  end

  defmodule UndefinedFragmentSpreadError do
    @moduledoc false
    defexception [:node]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_mod!: 1]

    def message(%__MODULE__{node: node = %{name: name}}) do
      "Undefined fragment spread found for #{inspect(name)} of #{format_mod!(node)} in #{format_loc!(node)}"
    end
  end

  defmodule UnsupportedOperationError do
    @moduledoc false
    defexception [:node, :operation]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_mod!: 1]

    def message(%__MODULE__{node: node = %{name: name}, operation: operation}) do
      "Schema does not support operation #{inspect(operation)} for #{inspect(name)} of #{format_mod!(node)} in #{format_loc!(node)}"
    end
  end

  defmodule State do
    @moduledoc false
    @enforce_keys [:library, :definitions, :selections, :variables]
    defstruct [:library, :definitions, :selections, :variables]

    def fetch_variable_definition!(%__MODULE__{variables: variables}, %Wormwood.Language.Variable{name: name}) do
      Map.fetch!(variables, name)
    end

    def push(state = %__MODULE__{definitions: definitions, selections: selections}, definition, selection) do
      definitions = [definition | definitions]
      selections = [selection | selections]
      %__MODULE__{state | definitions: definitions, selections: selections}
    end
  end

  @doc false
  def validate!(library = %Wormwood.Library{}, operation_definitions = [_ | _]) do
    if has_schema_definition?(library) do
      :ok =
        Enum.each(operation_definitions, fn operation_definition = %Wormwood.Language.OperationDefinition{} ->
          :ok = validate_operation_definition!(library, operation_definition)
        end)

      :ok
    else
      :ok
    end
  end

  @doc false
  def has_schema_definition?(%{types: types}) when is_map(types), do: map_size(types) > 0

  @doc false
  def validate_field!(
        state = %{library: library},
        field_definition = %Wormwood.Language.FieldDefinition{arguments: args1, type: type_reference},
        field = %Wormwood.Language.Field{arguments: args2, selection_set: selection_set}
      ) do
    :ok = validate_field_arguments!(State.push(state, field_definition, field), args1, args2)
    definition = Wormwood.Library.Validation.Typed.resolve!(library, type_reference)

    case definition do
      %{__struct__: module} when module in [Wormwood.Language.InterfaceTypeDefinition, Wormwood.Language.ObjectTypeDefinition] ->
        # Object-like type, selection set MUST be present.
        case selection_set do
          %Wormwood.Language.SelectionSet{selections: [_ | _]} ->
            validate_selection_set!(State.push(state, definition, field), selection_set)

          _ ->
            errors = [EmptySelectionSetError.exception(definition: definition, selection: field)]
            raise(Wormwood.Library.CompilationError, errors: errors)
        end

      %{__struct__: _} ->
        # Non-object-like type, selection set MUST be empty.
        case selection_set do
          %Wormwood.Language.SelectionSet{selections: [_ | _]} ->
            errors = [NonObjectSelectionError.exception(definition: definition, selection: field)]
            raise(Wormwood.Library.CompilationError, errors: errors)

          _ ->
            :ok
        end
    end
  end

  @doc false
  def validate_field_argument!(
        state,
        input_value_definition = %Wormwood.Language.InputValueDefinition{type: input_type_reference},
        _argument = %Wormwood.Language.Argument{value: value}
      ) do
    case value do
      %Wormwood.Language.Variable{} ->
        %Wormwood.Language.VariableDefinition{type: variable_type_reference} = State.fetch_variable_definition!(state, value)

        if Wormwood.Library.Validation.Typed.equivalent?(input_type_reference, variable_type_reference) do
          :ok
        else
          alias Wormwood.Library.Validation.Typed.TypedValueError, as: TypedValueError

          error =
            TypedValueError.exception(
              expected: input_type_reference,
              actual: variable_type_reference,
              parent: input_value_definition
            )

          raise(Wormwood.Library.CompilationError, errors: [error], reason: TypedValueError.reason(error))
        end

      %{__struct__: _} ->
        Wormwood.Library.Validation.Typed.validate_typed_value!(state.library, input_value_definition, input_type_reference, value)
    end
  end

  @doc false
  def validate_field_arguments!(
        state = %{definitions: [definition | _], selections: [selection | _]},
        input_value_definitions,
        arguments
      ) do
    case input_value_definitions do
      _ when is_nil(input_value_definitions) or input_value_definitions === [] ->
        # Arguments are not required, fail if they have been set on the field.
        case arguments do
          _ when is_nil(arguments) or arguments === [] ->
            :ok

          [_ | _] ->
            errors =
              Enum.map(arguments, fn argument ->
                FieldArgumentError.exception(definition: definition, argument: argument)
              end)

            raise(Wormwood.Library.CompilationError,
              errors: errors,
              reason: """
              Field definition specifies zero arguments.

              Please remove unrecognized arguments from field selection.
              """
            )
        end

      [_ | _] ->
        vals =
          Enum.reduce(input_value_definitions, Map.new(), fn
            val = %Wormwood.Language.InputValueDefinition{name: name}, acc ->
              Map.put(acc, name, val)
          end)

        args =
          case arguments do
            _ when is_nil(arguments) or arguments === [] ->
              Map.new()

            [_ | _] ->
              Enum.reduce(arguments, Map.new(), fn
                argument = %Wormwood.Language.Argument{name: name}, acc ->
                  Map.put(acc, name, argument)
              end)
          end

        unrecognized_arguments =
          Enum.reduce(vals, args, fn {name, val}, args ->
            case :maps.take(name, args) do
              {argument, new_args} ->
                :ok = validate_field_argument!(state, val, argument)
                new_args

              :error ->
                case val do
                  %{type: %Wormwood.Language.NonNullType{}} ->
                    errors = [FieldSelectionError.exception(definition: val, selection: selection)]

                    raise(Wormwood.Library.CompilationError,
                      errors: errors,
                      reason: """
                      Field definition specifies argument is of NonNullType.

                      Please add required argument to field selection.
                      """
                    )

                  %{__struct__: _} ->
                    args
                end
            end
          end)

        if map_size(unrecognized_arguments) === 0 do
          :ok
        else
          errors =
            Enum.map(unrecognized_arguments, fn {_, argument} ->
              FieldArgumentError.exception(definition: definition, argument: argument)
            end)

          raise(Wormwood.Library.CompilationError,
            errors: errors,
            reason: """
            Unrecognized arguments found that are not defined in the field definition.

            Please remove unrecognized arguments from field selection.
            """
          )
        end
    end
  end

  @doc false
  def validate_fragment_spread!(
        %{library: library = %{fragments: fragments}},
        fragment_spread = %Wormwood.Language.FragmentSpread{name: name}
      ) do
    if Map.has_key?(fragments, name) do
      :ok
    else
      errors = [UndefinedFragmentSpreadError.exception(node: fragment_spread)]

      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        All fragment spreads must be defined, but 1 undefined fragment spread was found.

        This module and/or its imported GraphQL is causing this error: #{inspect(library.module)}
        """
      )
    end
  end

  @doc false
  def validate_inline_fragment!(
        state = %{library: library},
        inline_fragment = %Wormwood.Language.InlineFragment{type_condition: type_condition, selection_set: selection_set}
      ) do
    {:ok, definition} = Wormwood.Library.Validation.Typed.validate_type_reference!(library, type_condition)

    case definition do
      %{__struct__: module} when module in [Wormwood.Language.InterfaceTypeDefinition, Wormwood.Language.ObjectTypeDefinition] ->
        validate_selection_set!(State.push(state, definition, inline_fragment), selection_set)

      %{__struct__: _} ->
        errors = [InlineFragmentTypeError.exception(definition: definition, selection: inline_fragment)]
        raise(Wormwood.Library.CompilationError, errors: errors)
    end
  end

  @doc false
  def validate_operation_definition!(
        library = %{schema: schema, types: types},
        operation_definition = %Wormwood.Language.OperationDefinition{
          operation: operation,
          selection_set: selection_set,
          variable_definitions: variable_definitions
        }
      ) do
    operation = to_string(operation)

    case Map.fetch(schema, operation) do
      {:ok, definition_name} ->
        definition = %Wormwood.Language.ObjectTypeDefinition{} = Map.fetch!(types, definition_name)
        {:ok, variable_definition_map} = validate_variable_definitions!(library, operation_definition, variable_definitions)

        state = %State{
          library: library,
          definitions: [definition],
          selections: [operation_definition],
          variables: variable_definition_map
        }

        :ok = validate_selection_set!(state, selection_set)
        :ok

      :error ->
        errors = [UnsupportedOperationError.exception(node: operation_definition, operation: operation)]
        raise(Wormwood.Library.CompilationError, errors: errors)
    end
  end

  @doc false
  def validate_selection_set!(state = %{definitions: [definition | _]}, %Wormwood.Language.SelectionSet{
        selections: selections = [_ | _]
      }) do
    :ok =
      Enum.each(selections, fn
        %Wormwood.Language.Field{name: "__typename"} ->
          :ok

        field = %Wormwood.Language.Field{name: field_name} ->
          field_definitions =
            case definition do
              %Wormwood.Language.InterfaceTypeDefinition{fields: field_definitions} ->
                field_definitions

              %Wormwood.Language.ObjectTypeDefinition{fields: field_definitions} ->
                field_definitions
            end

          field_definition = Enum.find(field_definitions, fn %{name: n} -> n === field_name end)

          if not is_nil(field_definition) do
            :ok = validate_field!(state, field_definition, field)
          else
            errors = [FieldSelectionError.exception(definition: definition, selection: field)]
            raise(Wormwood.Library.CompilationError, errors: errors)
          end

        fragment_spread = %Wormwood.Language.FragmentSpread{} ->
          :ok = validate_fragment_spread!(state, fragment_spread)

        inline_fragment = %Wormwood.Language.InlineFragment{} ->
          :ok = validate_inline_fragment!(state, inline_fragment)
      end)

    :ok
  end

  @doc false
  def validate_variable_definition!(
        library,
        _parent,
        _variable_definition = %Wormwood.Language.VariableDefinition{
          variable: variable,
          type: type_reference,
          default_value: default_value
        }
      ) do
    {:ok, _type} = Wormwood.Library.Validation.Typed.validate_type_reference!(library, type_reference)

    if is_nil(default_value) do
      :ok
    else
      Wormwood.Library.Validation.Typed.validate_typed_value!(library, variable, type_reference, default_value)
    end
  end

  @doc false
  def validate_variable_definitions!(_library, _parent, vds) when is_nil(vds) or vds === [] do
    {:ok, Map.new()}
  end

  def validate_variable_definitions!(library, parent, variable_definitions = [_ | _]) do
    folder = fn
      variable_definition = %Wormwood.Language.VariableDefinition{variable: %Wormwood.Language.Variable{name: name}}, acc ->
        :ok = validate_variable_definition!(library, parent, variable_definition)
        Map.put(acc, name, variable_definition)
    end

    variable_definition_map = Enum.reduce(variable_definitions, Map.new(), folder)
    {:ok, variable_definition_map}
  end
end
