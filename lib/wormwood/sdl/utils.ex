defmodule Wormwood.SDL.Utils do
  @type opts() :: Wormwood.SDL.Encoder.Opts.t()

  @spec encode_arguments(term(), opts()) :: iodata()
  def encode_arguments(term, _opts) when is_nil(term) or term == [] do
    []
  end

  def encode_arguments(list = [_ | _], opts) do
    [[?,, ?\s | head] | tail] = Enum.map(list, &[?,, ?\s, Wormwood.SDL.Encoder.encode(&1, opts)])
    [?(, head, tail, ?)]
  end

  @spec encode_default_value(term(), opts()) :: iodata()
  def encode_default_value(nil, _opts) do
    []
  end

  def encode_default_value(default_value, opts) do
    [?\s, ?=, ?\s, Wormwood.SDL.Encoder.encode(default_value, opts)]
  end

  @spec encode_directives(term(), opts()) :: iodata()
  def encode_directives(term, _opts) when is_nil(term) or term == [] do
    []
  end

  def encode_directives(list = [_ | _], opts) do
    Enum.map(list, &[?\s, Wormwood.SDL.Encoder.encode(&1, opts)])
  end

  @spec encode_description(term(), opts()) :: iodata()
  def encode_description(nil, _opts) do
    []
  end

  def encode_description(description, _opts = %{depth: depth}) do
    indent = :binary.copy("  ", depth)
    lines = :binary.split(description, [<<?\r, ?\n>>, <<?\n>>, <<?\r>>], [:global])

    [
      indent,
      ?",
      ?",
      ?",
      ?\n,
      for line <- lines, into: [] do
        encoded = escape_triple_quote(line, <<>>)
        [indent, encoded, ?\n]
      end,
      indent,
      ?",
      ?",
      ?",
      ?\n
    ]
  end

  @doc false
  defp escape_triple_quote(<<?", ?", ?", rest::binary()>>, acc) do
    escape_triple_quote(rest, <<acc::binary(), ?\\, ?", ?", ?">>)
  end

  defp escape_triple_quote(<<c, rest::binary()>>, acc) do
    escape_triple_quote(rest, <<acc::binary(), c>>)
  end

  defp escape_triple_quote(<<>>, acc) do
    acc
  end

  @spec encode_enum_values(term(), opts()) :: iodata()
  def encode_enum_values(term, _opts) when is_nil(term) or term == [] do
    []
  end

  def encode_enum_values(list = [_ | _], opts = %{depth: depth}) do
    indent = :binary.copy("  ", depth)
    [?\s, ?{, ?\n, Enum.map(list, &Wormwood.SDL.Encoder.encode(&1, %{opts | depth: depth + 1})), indent, ?}]
  end

  @spec encode_field_definitions(term(), opts()) :: iodata()
  def encode_field_definitions(term, _opts) when is_nil(term) or term == [] do
    []
  end

  def encode_field_definitions(field_definitions, opts = %{depth: depth}) do
    indent = :binary.copy("  ", depth)
    [?\s, ?{, ?\n, Enum.map(field_definitions, &Wormwood.SDL.Encoder.encode(&1, %{opts | depth: depth + 1})), indent, ?}]
  end

  @spec encode_interfaces(term(), opts()) :: iodata()
  def encode_interfaces(term, _opts) when is_nil(term) or term == [] do
    []
  end

  def encode_interfaces(list = [_ | _], opts) do
    [[?\s, ?&, ?\s | head] | tail] = Enum.map(list, &[?\s, ?&, ?\s, Wormwood.SDL.Encoder.encode(&1, opts)])
    [" implements ", head | tail]
  end

  @spec encode_name(term()) :: iodata()
  def encode_name(nil) do
    []
  end

  def encode_name(name) do
    to_string(name)
  end

  @spec encode_selection_set(term(), opts()) :: iodata()
  def encode_selection_set(term, _opts) when is_nil(term) or term == [] do
    []
  end

  def encode_selection_set(%{selections: []}, _opts) do
    []
  end

  def encode_selection_set(selection_set, opts) do
    [?\s | Wormwood.SDL.Encoder.encode(selection_set, opts)]
  end

  @spec encode_type_condition(term(), opts()) :: iodata()
  def encode_type_condition(nil, _opts) do
    []
  end

  def encode_type_condition(type_condition, opts) do
    [" on " | Wormwood.SDL.Encoder.encode(type_condition, opts)]
  end

  @spec encode_union_types(term(), opts()) :: iodata()
  def encode_union_types(term, _opts) when is_nil(term) or term == [] do
    []
  end

  def encode_union_types(list = [_ | _], opts) do
    [[?\s, ?|, ?\s | head] | tail] = Enum.map(list, &[?\s, ?|, ?\s, Wormwood.SDL.Encoder.encode(&1, opts)])
    [?\s, ?=, ?\s, head | tail]
  end

  def maybe_extend(description, label, opts = %{depth: depth}) when is_integer(depth) and depth >= 0 do
    indent = :binary.copy("  ", depth)

    header = [
      encode_description(description, opts),
      indent,
      label
    ]

    {header, opts}
  end

  def maybe_extend(description, label, {:extend, prefix, opts = %{depth: depth}}) when is_integer(depth) and depth >= 0 do
    indent = :binary.copy("  ", depth)

    header = [
      encode_description(description, opts),
      indent,
      prefix,
      label
    ]

    {header, opts}
  end
end
