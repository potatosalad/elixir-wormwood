defmodule Wormwood.SDL.Decoder do
  @spec tokenize!(Wormwood.Language.Source.t()) :: [tuple()] | no_return()
  def tokenize!(source = %Wormwood.Language.Source{body: body}) do
    case Wormwood.Lexer.tokenize(body) do
      {:ok, tokens} when is_list(tokens) ->
        tokens

      {:error, rest, loc} ->
        raise(Wormwood.SDL.DecodeError, {source, {:lexer, rest, loc}})
    end
  end

  @spec parse!(Wormwood.Language.Source.t()) :: Wormwood.Language.Document.t() | no_return()
  def parse!(source = %Wormwood.Language.Source{}) do
    case tokenize!(source) do
      [] ->
        %Wormwood.Language.Document{source: source}

      tokens = [_ | _] ->
        case :wormwood_parser.parse(tokens) do
          {:ok, document = %Wormwood.Language.Document{source: nil}} ->
            %{document | source: source}

          {:error, raw_error} ->
            raise(Wormwood.SDL.DecodeError, {source, raw_error})
        end
    end
  end
end
