defmodule Wormwood.GraphQL do
  defmacro gql!(module, input) do
    module = Macro.expand(module, __CALLER__)
    operation = Macro.escape(do_gql!(__CALLER__, module, input))

    quote do
      unquote(operation)
    end
  end

  defmacro operation!(module, name) do
    module = Macro.expand(module, __CALLER__)
    operation = Macro.escape(do_operation!(__CALLER__, module, name))

    quote do
      unquote(operation)
    end
  end

  @doc false
  defp do_gql!(env, module, input) when is_atom(module) and is_binary(input) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__wormwood_library__, 0) do
      source = %Wormwood.Language.Source{name: env.file, line: env.line, body: input}

      case Wormwood.SDL.decode(source) do
        {:ok, document = %{source: source}} ->
          draft = %Wormwood.Library.Draft{module: env.module}
          draft = Wormwood.Library.Draft.import_document!(draft, document)

          case draft do
            %Wormwood.Library.Draft{
              schemas: [],
              directives: [],
              types: [],
              operations: operations = [%{name: name}],
              fragments: fragments
            } ->
              library = %Wormwood.Library{module: original_module} = module.__wormwood_library__()
              operation_library = %{library | module: env.module}
              operation_library = Wormwood.Library.import_fragments!(operation_library, fragments)
              operation_library = Wormwood.Library.import_operations!(operation_library, operations)
              extracted = %Wormwood.Language.Document{} = Wormwood.Library.extract_operation(operation_library, name)
              source = %{source | body: :erlang.iolist_to_binary(Wormwood.SDL.encode(extracted))}
              extracted = %{extracted | source: source}
              library = %{operation_library | module: original_module}
              Wormwood.Library.Operation.compile!(env, library, extracted)
          end
      end
    else
      raise("unable to find module: #{inspect(module)}")
    end
  end

  @doc false
  defp do_operation!(env, module, name) when is_atom(module) and is_binary(name) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__wormwood_library__, 0) do
      library = %Wormwood.Library{module: original_module} = module.__wormwood_library__()
      operation_library = %{library | module: env.module}

      case Wormwood.Library.extract_operation(operation_library, name) do
        extracted = %Wormwood.Language.Document{} ->
          body = :erlang.iolist_to_binary(Wormwood.SDL.encode(extracted))
          source = %Wormwood.Language.Source{name: env.file, line: env.line, body: body}
          extracted = %{extracted | source: source}
          library = %{operation_library | module: original_module}
          Wormwood.Library.Operation.compile!(env, library, extracted)

        nil ->
          errors = [Wormwood.Library.Operation.NotFoundError.exception(name: name, library: library)]

          raise(Wormwood.Library.CompilationError,
            errors: errors,
            reason: """
            Operations must be defined by name in order to use the #{inspect(module)}.operation!/1 macro.
            """
          )
      end
    else
      raise("unable to find module: #{inspect(module)}")
    end
  end

  def format_file!(file) when is_binary(file) do
    string = File.read!(file)
    format_string!(string)
  end

  def format_string!(binary) when is_binary(binary) do
    sdl = Wormwood.SDL.decode!(binary)
    Wormwood.SDL.encode(sdl)
  end

  def format_string!(list) when is_list(list) do
    format_string!(:erlang.iolist_to_binary(list))
  end
end
