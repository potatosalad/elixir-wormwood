defmodule Wormwood.Library do
  defstruct module: nil,
            schema: %{},
            directives: %{},
            types: %{},
            operations: %{},
            fragments: %{}

  defmacro __using__(_opt) do
    quote do
      use Wormwood.Library.Notation
      import unquote(__MODULE__), only: :macros

      @after_compile unquote(__MODULE__)
    end
  end

  def __after_compile__(env, _) do
    _ = env
    []
  end

  @doc false
  def from_draft!(
        draft = %Wormwood.Library.Draft{
          module: module,
          schemas: schemas,
          directives: directives,
          types: types,
          operations: operations,
          fragments: fragments
        }
      ) do
    schema =
      Enum.reduce(schemas, Map.new(), fn %{fields: fields}, acc ->
        Enum.reduce(fields, acc, fn %Wormwood.Language.FieldDefinition{name: name, type: %Wormwood.Language.NamedType{name: type}},
                                    acc ->
          Map.put(acc, name, type)
        end)
      end)

    types =
      Enum.reduce(types, Map.new(), fn type = %{name: name}, acc ->
        Map.put(acc, name, type)
      end)

    %__MODULE__{module: module, schema: schema, types: types}
    |> import_fragments!(fragments)
    |> import_operations!(operations)
  end

  @doc false
  def import_fragments!(library = %__MODULE__{}, []), do: library

  def import_fragments!(library = %__MODULE__{fragments: old_fragments}, fragments = [_ | _]) do
    new_fragments =
      Enum.reduce(fragments, old_fragments, fn new_fragment = %Wormwood.Language.Fragment{name: name}, acc ->
        case Map.fetch(acc, name) do
          {:ok, old_fragment} ->
            alias Wormwood.Library.Validation.Uniqueness.DuplicateError, as: DuplicateError

            errors = [
              DuplicateError.exception(name: name, node: old_fragment, subject: "fragment"),
              DuplicateError.exception(name: name, node: new_fragment, subject: "fragment")
            ]

            raise(Wormwood.Library.CompilationError,
              errors: errors,
              reason: """
              Fragment definitions must be unique by name, but 2 duplicates were found.
              """
            )

          :error ->
            Map.put(acc, name, new_fragment)
        end
      end)

    library = %__MODULE__{library | fragments: new_fragments}
    :ok = Wormwood.Library.Validation.FragmentUntyped.validate!(library, fragments)
    :ok = Wormwood.Library.Validation.FragmentTyped.validate!(library, fragments)
    library
  end

  @doc false
  def import_operations!(library = %__MODULE__{}, []), do: library

  def import_operations!(library = %__MODULE__{operations: old_operations}, operations = [_ | _]) do
    new_operations =
      Enum.reduce(operations, old_operations, fn new_operation = %Wormwood.Language.OperationDefinition{name: name}, acc ->
        case Map.fetch(acc, name) do
          {:ok, old_operation} ->
            alias Wormwood.Library.Validation.Uniqueness.DuplicateError, as: DuplicateError

            errors = [
              DuplicateError.exception(name: name, node: old_operation, subject: Wormwood.Language.subject(old_operation)),
              DuplicateError.exception(name: name, node: new_operation, subject: Wormwood.Language.subject(new_operation))
            ]

            raise(Wormwood.Library.CompilationError,
              errors: errors,
              reason: """
              Operation definitions must be unique by name, but 2 duplicates were found.
              """
            )

          :error ->
            Map.put(acc, name, new_operation)
        end
      end)

    library = %__MODULE__{library | operations: new_operations}
    :ok = Wormwood.Library.Validation.OperationUntyped.validate!(library, operations)
    :ok = Wormwood.Library.Validation.OperationTyped.validate!(library, operations)
    library
  end
end
