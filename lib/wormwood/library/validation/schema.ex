defmodule Wormwood.Library.Validation.Schema do
  @moduledoc false

  defmodule DuplicateArgumentError do
    @moduledoc false
    defexception [:parent, :argument]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_mod!: 1]

    def message(%__MODULE__{parent: %{name: parent_name}, argument: node = %{name: argument_name}}) do
      "Duplicate argument found for #{inspect(argument_name)} on field #{inspect(parent_name)} in #{format_loc!(node)}"
    end
  end

  defmodule DuplicateFieldDefinitionError do
    @moduledoc false
    defexception [:parent, :field_definition]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_mod!: 1]

    def message(%__MODULE__{parent: parent, field_definition: node = %{name: name}}) do
      subject = Wormwood.Language.subject(parent)

      case parent do
        %Wormwood.Language.SchemaDefinition{} ->
          "Duplicate field definition found for #{inspect(name)} on #{inspect(subject)} of #{format_mod!(parent)} in #{
            format_loc!(node)
          }"

        %{name: parent_name} ->
          "Duplicate field definition found for #{inspect(name)} on #{inspect(parent_name)} as #{inspect(subject)} of #{
            format_mod!(parent)
          } in #{format_loc!(node)}"
      end
    end
  end

  defmodule DuplicateInputValueDefinitionError do
    @moduledoc false
    defexception [:parent, :input_value_definition]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_mod!: 1]

    def message(%__MODULE__{parent: parent, input_value_definition: node = %{name: name}}) do
      subject = Wormwood.Language.subject(parent)

      case parent do
        %Wormwood.Language.SchemaDefinition{} ->
          "Duplicate input value definition found for #{inspect(name)} on #{inspect(subject)} of #{format_mod!(parent)} in #{
            format_loc!(node)
          }"

        %{name: parent_name} ->
          "Duplicate input value definition found for #{inspect(name)} on #{inspect(parent_name)} as #{inspect(subject)} of #{
            format_mod!(parent)
          } in #{format_loc!(node)}"
      end
    end
  end

  defmodule OrphanError do
    @moduledoc false
    defexception [:node]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_mod!: 1]

    def message(%__MODULE__{node: node = %{name: name}}) do
      subject = Wormwood.Language.subject(node)
      "Orphan found for #{inspect(name)} as #{inspect(subject)} of #{format_mod!(node)} in #{format_loc!(node)}"
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
  def validate!(draft = %Wormwood.Library.Draft{}) do
    if has_schema_definition?(draft) do
      :ok = validate_schema_definition!(draft)
      :ok
    else
      :ok
    end
  end

  @doc false
  def has_schema_definition?(%{schemas: []}), do: false
  def has_schema_definition?(%{schemas: [_]}), do: true

  @doc false
  def validate_argument!(draft, argument, refs) do
    case argument do
      %Wormwood.Language.InputValueDefinition{type: type_reference} ->
        {:ok, type} = validate_type_reference!(draft, type_reference)
        refs = maybe_validate_type_definition!(draft, type, refs)
        refs
    end
  end

  @doc false
  def validate_arguments!(draft, field_definition = %Wormwood.Language.FieldDefinition{}, arguments, refs) do
    refs =
      Enum.reduce(arguments, refs, fn
        argument, refs ->
          validate_argument!(draft, argument, refs)
      end)

    possible_duplicates =
      Enum.reduce(arguments, Map.new(), fn argument = %{name: name}, acc ->
        Map.update(acc, name, [argument], &[argument | &1])
      end)

    duplicates = Enum.reject(possible_duplicates, fn {_, nodes} -> length(nodes) === 1 end)

    if duplicates === [] do
      refs
    else
      {duplicate_count, errors} =
        Enum.reduce(duplicates, {0, []}, fn {_, dups}, acc ->
          Enum.reduce(dups, acc, fn argument = %{__struct__: _}, {count, errs} ->
            error = DuplicateArgumentError.exception(parent: field_definition, argument: argument)
            {count + 1, [error | errs]}
          end)
        end)

      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        Argument definitions must be unique by name, but #{duplicate_count} duplicates were found.

        This module and/or its imported GraphQL is causing this error: #{inspect(draft.module)}
        """
      )
    end
  end

  @doc false
  def validate_field_definition!(
        draft,
        field_definition = %Wormwood.Language.FieldDefinition{arguments: arguments, type: type_reference},
        refs
      ) do
    {:ok, type} = validate_type_reference!(draft, type_reference)
    refs = maybe_validate_type_definition!(draft, type, refs)
    refs = validate_arguments!(draft, field_definition, arguments, refs)
    refs
  end

  @doc false
  def validate_field_definitions!(draft, parent, field_definitions, refs) do
    refs =
      Enum.reduce(field_definitions, refs, fn
        field_definition = %Wormwood.Language.FieldDefinition{}, refs ->
          validate_field_definition!(draft, field_definition, refs)
      end)

    possible_duplicates =
      Enum.reduce(field_definitions, Map.new(), fn field_definition = %{name: name}, acc ->
        Map.update(acc, name, [field_definition], &[field_definition | &1])
      end)

    duplicates = Enum.reject(possible_duplicates, fn {_, nodes} -> length(nodes) === 1 end)

    if duplicates === [] do
      refs
    else
      {duplicate_count, errors} =
        Enum.reduce(duplicates, {0, []}, fn {_, dups}, acc ->
          Enum.reduce(dups, acc, fn field_definition = %{__struct__: _}, {count, errs} ->
            error = DuplicateFieldDefinitionError.exception(parent: parent, field_definition: field_definition)
            {count + 1, [error | errs]}
          end)
        end)

      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        Field definitions must be unique by name, but #{duplicate_count} duplicates were found.

        This module and/or its imported GraphQL is causing this error: #{inspect(draft.module)}
        """
      )
    end
  end

  @doc false
  def validate_input_value_definition!(draft, input_value_definition, refs) do
    case input_value_definition do
      %Wormwood.Language.InputValueDefinition{type: type_reference} ->
        {:ok, type} = validate_type_reference!(draft, type_reference)
        refs = maybe_validate_type_definition!(draft, type, refs)
        refs
    end
  end

  @doc false
  def validate_input_value_definitions!(draft, parent, input_value_definitions, refs) do
    refs =
      Enum.reduce(input_value_definitions, refs, fn
        input_value_definition, refs ->
          validate_input_value_definition!(draft, input_value_definition, refs)
      end)

    possible_duplicates =
      Enum.reduce(input_value_definitions, Map.new(), fn input_value_definition = %{name: name}, acc ->
        Map.update(acc, name, [input_value_definition], &[input_value_definition | &1])
      end)

    duplicates = Enum.reject(possible_duplicates, fn {_, nodes} -> length(nodes) === 1 end)

    if duplicates === [] do
      refs
    else
      {duplicate_count, errors} =
        Enum.reduce(duplicates, {0, []}, fn {_, dups}, acc ->
          Enum.reduce(dups, acc, fn input_value_definition = %{__struct__: _}, {count, errs} ->
            error = DuplicateInputValueDefinitionError.exception(parent: parent, input_value_definition: input_value_definition)
            {count + 1, [error | errs]}
          end)
        end)

      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        Input value definitions must be unique by name, but #{duplicate_count} duplicates were found.

        This module and/or its imported GraphQL is causing this error: #{inspect(draft.module)}
        """
      )
    end
  end

  @doc false
  def validate_schema_definition!(
        draft = %{schemas: [schema_definition = %Wormwood.Language.SchemaDefinition{fields: fields = [_ | _]}], types: all_types}
      ) do
    all_types = MapSet.new(all_types)
    referenced_types = validate_field_definitions!(draft, schema_definition, fields, MapSet.new())
    orphan_types = MapSet.difference(all_types, referenced_types)

    {_, orphan_types} =
      Enum.reduce(orphan_types, {referenced_types, MapSet.new()}, fn
        %Wormwood.Language.ScalarTypeDefinition{name: name}, acc = {_refs, _orphans}
        when name in ["Boolean", "Float", "ID", "Int", "String"] ->
          # Ignore pre-defined Scalar orphans
          acc

        type = %Wormwood.Language.ObjectTypeDefinition{interfaces: interfaces = [_ | _]}, {refs, orphans} ->
          # Ignore Object with referenced interface implementations
          is_interface_referenced =
            Enum.any?(interfaces, fn interface ->
              {:ok, type} = validate_type_reference!(draft, interface)
              MapSet.member?(referenced_types, type)
            end)

          if is_interface_referenced do
            refs = validate_type_definition!(draft, type, refs)
            {refs, orphans}
          else
            orphans = MapSet.put(orphans, type)
            {refs, orphans}
          end

        type, {refs, orphans} ->
          orphans = MapSet.put(orphans, type)
          {refs, orphans}
      end)

    if MapSet.size(orphan_types) === 0 do
      :ok
    else
      orphan_count = MapSet.size(orphan_types)

      errors =
        Enum.map(orphan_types, fn node = %{__struct__: _, name: _} ->
          OrphanError.exception(node: node)
        end)

      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        All types must be referenced and reachable within a schema definition, but #{orphan_count} orphan(s) were found.

        This module and/or its imported GraphQL is causing this error: #{inspect(draft.module)}
        """
      )
    end
  end

  @doc false
  def maybe_validate_type_definition!(draft, type, refs) do
    if MapSet.member?(refs, type) do
      refs
    else
      validate_type_definition!(draft, type, refs)
    end
  end

  @doc false
  def validate_type_definition!(draft, type, refs) do
    refs = MapSet.put(refs, type)

    case type do
      %Wormwood.Language.EnumTypeDefinition{values: _values = [_ | _]} ->
        refs

      %Wormwood.Language.InputObjectTypeDefinition{fields: fields} ->
        refs = validate_input_value_definitions!(draft, type, fields, refs)
        refs

      %Wormwood.Language.InterfaceTypeDefinition{fields: fields} ->
        refs = validate_field_definitions!(draft, type, fields, refs)
        refs

      %Wormwood.Language.ObjectTypeDefinition{fields: fields, interfaces: interfaces} ->
        refs = validate_field_definitions!(draft, type, fields, refs)
        refs = validate_type_references!(draft, interfaces, refs)
        refs

      %Wormwood.Language.ScalarTypeDefinition{} ->
        refs

      %Wormwood.Language.UnionTypeDefinition{types: types} ->
        refs = validate_type_references!(draft, types, refs)
        refs
    end
  end

  @doc false
  def validate_type_reference!(draft, %Wormwood.Language.ListType{type: type}), do: validate_type_reference!(draft, type)
  def validate_type_reference!(draft, %Wormwood.Language.NonNullType{type: type}), do: validate_type_reference!(draft, type)

  def validate_type_reference!(draft = %{types: types}, node = %Wormwood.Language.NamedType{name: name}) do
    type = Enum.find(types, fn %{name: other} -> name === other end)

    if is_nil(type) do
      errors = [UndefinedTypeReferenceError.exception(node: node)]

      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        All referenced types must be defined within a schema definition, but 1 undefined type reference was found.

        This module and/or its imported GraphQL is causing this error: #{inspect(draft.module)}
        """
      )
    else
      {:ok, type}
    end
  end

  @doc false
  def validate_type_references!(draft, type_references, refs) do
    Enum.reduce(type_references, refs, fn
      type_reference, refs ->
        {:ok, type} = validate_type_reference!(draft, type_reference)
        maybe_validate_type_definition!(draft, type, refs)
    end)
  end
end
