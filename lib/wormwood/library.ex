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

  def extract_fragment(module, name) when is_atom(module) do
    extract_fragment(%__MODULE__{} = module.__wormwood_library__(), name)
  end

  def extract_fragment(library = %__MODULE__{}, name) do
    case lookup_fragment(library, name) do
      fragment = %Wormwood.Language.Fragment{name: fragment_name} ->
        seen = Map.new()
        seen = Map.put(seen, fragment_name, fragment)
        fragments = do_extract_fragment!(library, fragment, seen)
        definitions = Enum.sort(Map.values(fragments))
        %Wormwood.Language.Document{definitions: definitions}

      nil ->
        nil
    end
  end

  @doc false
  defp do_extract_fragment!(library = %__MODULE__{}, fragment, seen) do
    {_, fragments} =
      Wormwood.Traversal.reduce(fragment, seen, fn
        fragment_spread = %Wormwood.Language.FragmentSpread{}, _parent, _path, acc ->
          next_fragment = %Wormwood.Language.Fragment{name: fragment_name} = lookup_fragment(library, fragment_spread)

          if Map.has_key?(acc, fragment_name) do
            :cont
          else
            acc = Map.put(acc, fragment_name, next_fragment)
            acc = do_extract_fragment!(library, next_fragment, acc)
            {:skip, acc}
          end

        _node, _parent, _path, _acc ->
          :cont
      end)

    fragments
  end

  def extract_operation(module, name) when is_atom(module) do
    extract_operation(%__MODULE__{} = module.__wormwood_library__(), name)
  end

  def extract_operation(library = %__MODULE__{}, name) do
    case lookup_operation(library, name) do
      operation_definition = %Wormwood.Language.OperationDefinition{} ->
        {_, fragments} =
          Wormwood.Traversal.reduce(operation_definition, Map.new(), fn
            fragment_spread = %Wormwood.Language.FragmentSpread{}, _parent, _path, acc ->
              next_fragment = %Wormwood.Language.Fragment{name: fragment_name} = lookup_fragment(library, fragment_spread)

              if Map.has_key?(acc, fragment_name) do
                :cont
              else
                acc = Map.put(acc, fragment_name, next_fragment)
                acc = do_extract_fragment!(library, next_fragment, acc)
                {:skip, acc}
              end

            _node, _parent, _path, _acc ->
              :cont
          end)

        definitions = Enum.sort(Map.values(fragments))
        %Wormwood.Language.Document{definitions: [operation_definition | definitions]}

      nil ->
        nil
    end
  end

  def lookup_directive(module, name) when is_atom(module) do
    lookup_directive(%__MODULE__{} = module.__wormwood_library__(), name)
  end

  def lookup_directive(%__MODULE__{directives: directives}, name) do
    Map.get(directives, name, nil)
  end

  def lookup_fragment(module, name) when is_atom(module) do
    lookup_fragment(%__MODULE__{} = module.__wormwood_library__(), name)
  end

  def lookup_fragment(library = %__MODULE__{}, %Wormwood.Language.FragmentSpread{name: name}) do
    lookup_fragment(library, name)
  end

  def lookup_fragment(%__MODULE__{fragments: fragments}, name) do
    Map.get(fragments, name, nil)
  end

  def lookup_operation(module, name) when is_atom(module) do
    lookup_operation(%__MODULE__{} = module.__wormwood_library__(), name)
  end

  def lookup_operation(%__MODULE__{operations: operations}, name) do
    Map.get(operations, name, nil)
  end

  def lookup_type(module, name) when is_atom(module) do
    module.__wormwood_type__(name)
  end

  def lookup_type(%__MODULE__{types: types}, name) do
    Map.get(types, name, nil)
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
      Enum.reduce(operations, old_operations, fn
        new_operation = %Wormwood.Language.OperationDefinition{name: nil}, acc ->
          alias Wormwood.Library.Validation.Uniqueness.NoNameError, as: NoNameError

          errors = [
            NoNameError.exception(node: new_operation)
          ]

          raise(Wormwood.Library.CompilationError,
            errors: errors,
            reason: """
            Operation definitions MUST be named, but 1 no name found.
            """
          )

        new_operation = %Wormwood.Language.OperationDefinition{name: name}, acc ->
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
                Operation definitions MUST be unique by name, but 2 duplicates were found.
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
