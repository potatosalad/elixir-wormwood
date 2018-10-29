defmodule Wormwood.Library.Notation do
  Module.register_attribute(__MODULE__, :placement, accumulate: true)

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: :macros
      @before_compile unquote(__MODULE__)
    end
  end

  ### Macro API ###

  @placement {:import_graphql, [toplevel: true]}
  defmacro import_graphql(embedded \\ nil, opts \\ []) do
    do_import_graphql(__CALLER__, embedded, opts)
  end

  @doc false
  defp do_import_graphql(env, opts = [_ | _], []) do
    do_import_graphql(env, nil, opts)
  end

  defp do_import_graphql(env, nil, opts) do
    case Keyword.fetch(opts, :path) do
      {:ok, path} ->
        path = Path.expand(path)
        data = File.read!(path)

        body =
          case Keyword.fetch(opts, :json) do
            {:ok, true} ->
              json = OJSON.decode!(data)
              document = Wormwood.Schema.JSON.load!(json)
              :erlang.iolist_to_binary(Wormwood.SDL.encode(document))

            other when other in [{:ok, false}, :error] ->
              data
          end

        source = %Wormwood.Language.Source{name: path, body: body}
        Module.put_attribute(env.module, :external_resource, path)
        do_import_graphql(env, source, Keyword.delete(opts, :path))

      :error ->
        raise(
          Wormwood.Library.Notation.Error,
          "Must provide `:path` option to `import_graphql` unless passing a raw GraphQL string as the first argument"
        )
    end
  end

  defp do_import_graphql(env, graphql, opts) when is_binary(graphql) do
    source = %Wormwood.Language.Source{name: env.file, line: env.line, body: graphql}
    do_import_graphql(env, source, opts)
  end

  defp do_import_graphql(env, source = %Wormwood.Language.Source{}, _opts) do
    case Wormwood.SDL.decode(source) do
      {:ok, document} ->
        Module.put_attribute(env.module, :__wormwood_graphql_documents__, [
          document | Module.get_attribute(env.module, :__wormwood_graphql_documents__) || []
        ])
    end
  end

  defmacro __before_compile__(env) do
    draft = %Wormwood.Library.Draft{
      module: env.module
    }

    drafts =
      (Module.get_attribute(env.module, :__wormwood_graphql_documents__) || [])
      |> List.flatten()
      |> Enum.map(fn document ->
        Wormwood.Library.Draft.import_document!(draft, document)
      end)

    library = Wormwood.Library.Draft.build!([draft | drafts])

    type_functions = build_type_functions(env, library)

    quote do
      defmacro gql!(input) do
        quote do
          require Wormwood.GraphQL
          Wormwood.GraphQL.gql!(unquote(__MODULE__), unquote(input))
        end
      end

      defmacro operation!(name) do
        quote do
          require Wormwood.GraphQL
          Wormwood.GraphQL.operation!(unquote(__MODULE__), unquote(name))
        end
      end

      def __wormwood_library__ do
        unquote(Macro.escape(library, unquote: true))
      end

      unquote_splicing(type_functions)
    end
  end

  @doc false
  defp build_type_functions(env, %{types: types}) do
    do_build_type_function(env, Map.to_list(types), [])
  end

  @doc false
  defp do_build_type_function(_env, [], functions) do
    :lists.reverse([
      quote do
        def __wormwood_type__(_), do: nil
      end
      | functions
    ])
  end

  defp do_build_type_function(env, [{name, type} | rest], functions) do
    type = Macro.escape(type)

    function =
      quote do
        def __wormwood_type__(unquote(name)), do: unquote(type)
      end

    do_build_type_function(env, rest, [function | functions])
  end
end
