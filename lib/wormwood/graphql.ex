defmodule Wormwood.GraphQL do
  defmacro gql!(module, input) do
    module = Macro.expand(module, __CALLER__)
    document = Macro.escape(do_gql!(__CALLER__, module, input))

    quote do
      unquote(document)
    end
  end

  @doc false
  defp do_gql!(env, module, input) when is_atom(module) and is_binary(input) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__wormwood_library__, 0) do
      source = %Wormwood.Language.Source{name: env.file, line: env.line, body: input}

      case Wormwood.SDL.decode(source) do
        {:ok, document} ->
          document
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
