defmodule Wormwood.Library.Validation.Uniqueness do
  @moduledoc false

  defmodule DuplicateError do
    @moduledoc false
    defexception [:node, :subject, name: nil]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_mod!: 1]

    def message(%__MODULE__{name: name, node: node, subject: subject}) do
      if is_nil(name) do
        "Duplicate found for #{inspect(subject)} of #{format_mod!(node)} in #{format_loc!(node)}"
      else
        "Duplicate found for #{inspect(name)} as #{inspect(subject)} of #{format_mod!(node)} in #{format_loc!(node)}"
      end
    end
  end

  @doc false
  def validate!(list) when is_list(list) do
    :ok = validate_no_more_than_one_schema!(list)
    :ok = validate_unique_directive_definitions!(list)
    :ok = validate_unique_type_definitions!(list)
    :ok = validate_unique_operation_definitions!(list)
    :ok = validate_unique_fragment_definitions!(list)
    :ok
  end

  @doc false
  def validate_no_more_than_one_schema!(list) when is_list(list) do
    schema_count = Enum.reduce(list, 0, fn %{schemas: schemas}, count -> count + length(schemas) end)

    if schema_count > 1 do
      [%{module: module} | _] = list
      schemas = Enum.flat_map(list, fn %{schemas: schemas} -> schemas end)

      errors =
        Enum.map(schemas, fn node = %{__struct__: _} ->
          DuplicateError.exception(node: node, subject: "schema")
        end)

      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        Only one schema definition is allowed, but #{schema_count} were found.

        This module and/or its imported GraphQL is causing this error: #{inspect(module)}
        """
      )
    else
      :ok
    end
  end

  @doc false
  def validate_unique_directive_definitions!(list) when is_list(list) do
    do_validate_unique_definitions!(list, :directives, fn
      nil -> "Directive"
      %Wormwood.Language.DirectiveDefinition{} -> "directive"
    end)
  end

  @doc false
  def validate_unique_fragment_definitions!(list) when is_list(list) do
    do_validate_unique_definitions!(list, :fragments, fn
      nil -> "Fragment"
      %Wormwood.Language.Fragment{} -> "fragment"
    end)
  end

  @doc false
  def validate_unique_operation_definitions!(list) when is_list(list) do
    do_validate_unique_definitions!(list, :operations, fn
      nil -> "Operation"
      %Wormwood.Language.OperationDefinition{operation: operation} -> to_string(operation)
    end)
  end

  @doc false
  def validate_unique_type_definitions!(list) when is_list(list) do
    do_validate_unique_definitions!(list, :types, fn
      nil -> "Type"
      node -> Wormwood.Language.subject(node)
    end)
  end

  @doc false
  defp check_for_duplicate_errors(possible_duplicates, subject_fun)
       when is_map(possible_duplicates) and is_function(subject_fun, 1) do
    duplicates = Enum.reject(possible_duplicates, fn {_, values} -> length(values) === 1 end)

    case duplicates do
      [] ->
        false

      [_ | _] ->
        {duplicate_count, errors} =
          Enum.reduce(duplicates, {0, []}, fn {name, dups}, acc ->
            Enum.reduce(dups, acc, fn node = %{__struct__: _}, {count, errs} ->
              error = DuplicateError.exception(name: name, node: node, subject: subject_fun.(node))
              {count + 1, [error | errs]}
            end)
          end)

        errors = :lists.reverse(errors)
        {true, duplicate_count, errors}
    end
  end

  @doc false
  defp do_validate_unique_definitions!(list, key, subject_fun)
       when is_list(list) and is_atom(key) and is_function(subject_fun, 1) do
    elements =
      Enum.reduce(list, Map.new(), fn draft, acc ->
        Enum.reduce(Map.fetch!(draft, key), acc, fn node = %{name: name}, acc ->
          Map.update(acc, name, [node], &[node | &1])
        end)
      end)

    case check_for_duplicate_errors(elements, subject_fun) do
      {true, duplicate_count, errors} ->
        [%{module: module} | _] = list

        raise(Wormwood.Library.CompilationError,
          errors: errors,
          reason: """
          #{subject_fun.(nil)} definitions must be unique by name, but #{duplicate_count} duplicates were found.

          This module and/or its imported GraphQL is causing this error: #{inspect(module)}
          """
        )

      false ->
        :ok
    end
  end
end
