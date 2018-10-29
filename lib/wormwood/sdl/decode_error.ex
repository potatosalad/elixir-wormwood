defmodule Wormwood.SDL.DecodeError do
  @moduledoc false
  defexception file: nil, description: nil, locations: []

  @type loc_t() :: %{optional(any()) => any(), line: pos_integer(), column: pos_integer()}
  @type t() :: %__MODULE__{description: String.t(), locations: [loc_t()]}

  @spec exception({Wormwood.Language.Source.t(), {integer(), :wormwood_parser, [charlist()]}}) :: t()
  def exception({%Wormwood.Language.Source{name: file}, {{line, column}, :wormwood_parser, msgs}}) do
    description = msgs |> Enum.map(&to_string/1) |> Enum.join("")
    %__MODULE__{file: file, description: description, locations: [%{line: line, column: column}]}
  end

  @spec exception({Wormwood.Language.Source.t(), {:lexer, String.t(), {line :: pos_integer(), column :: pos_integer()}}}) :: t()
  def exception({%Wormwood.Language.Source{name: file}, {:lexer, rest, {line, column}}}) do
    sample = sample_body(rest)
    description = "parsing failed at #{inspect(sample)}"
    %__MODULE__{file: file, description: description, locations: [%{line: line, column: column}]}
  end

  def message(%__MODULE__{file: file, description: description, locations: [%{line: line, column: column} | _]}) do
    format_file_line_column(relative_to_cwd(file), line, column) <> " " <> description
  end

  def format_file_line_column(file, line, column) do
    file =
      if is_nil(file) do
        "(nofile)"
      else
        file
      end

    if is_integer(column) and column > 0 do
      Exception.format_file_line(file, line, "#{column}:")
    else
      Exception.format_file_line(file, line)
    end
  end

  defp relative_to_cwd(nil), do: nil
  defp relative_to_cwd(file), do: Path.relative_to_cwd(file)

  defp sample_body(<<sample::binary-size(10), _::binary()>>), do: sample
  defp sample_body(body), do: body
end
