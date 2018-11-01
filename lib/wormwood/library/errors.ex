defmodule Wormwood.Library.Errors do
  @moduledoc false

  @doc false
  def format_indent!(string, 0) when is_binary(string) do
    string
  end

  def format_indent!(string, depth) when is_binary(string) and is_integer(depth) and depth > 0 do
    indent = :binary.copy(<<?\s>>, depth)

    case :binary.split(string, [<<?\r, ?\n>>, <<?\n>>], [:global, :trim]) do
      [] ->
        <<>>

      [head | tail] ->
        tail = Enum.map(tail, &(indent <> &1))
        Enum.join([head | tail], <<?\n>>)
    end
  end

  def format_indent!(iodata, depth) when is_list(iodata) and is_integer(depth) and depth >= 0 do
    string = :erlang.iolist_to_binary(iodata)
    format_indent!(string, depth)
  end

  @doc false
  def format_loc!(%{file: file, line: line, column: column}) do
    file =
      if File.regular?(file) do
        Path.relative_to_cwd(file)
      else
        file
      end

    "#{file}:#{line}:#{column}"
  end

  def format_loc!(%{loc: loc = %{file: _, line: _, column: _}}) do
    format_loc!(loc)
  end

  def format_loc!(%{loc: nil}) do
    "(nofile)"
  end

  @doc false
  def format_mod!(module) when is_atom(module) do
    :lists.last(Module.split(module))
  end

  def format_mod!(%{__struct__: module}) when is_atom(module) do
    format_mod!(module)
  end

  @doc false
  def format_sdl!(definition) do
    :erlang.iolist_to_binary(Wormwood.SDL.encode(definition))
  end

  @doc false
  def format_sdl!(definition, 0) do
    format_sdl!(definition)
  end

  def format_sdl!(definition, depth) when is_integer(depth) and depth > 0 do
    definition |> format_sdl!() |> format_indent!(depth)
  end
end
