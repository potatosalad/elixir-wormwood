defmodule Wormwood.SDL.Utils do
  @spec encode_arguments(term(), non_neg_integer()) :: iodata()
  def encode_arguments(term, _depth) when is_nil(term) or term == [] do
    []
  end

  def encode_arguments(list = [_ | _], depth) do
    [[?,, ?\s | head] | tail] = Enum.map(list, &[?,, ?\s, Wormwood.SDL.Encoder.encode(&1, depth)])
    [?(, head, tail, ?)]
  end

  @spec encode_default_value(term(), non_neg_integer()) :: iodata()
  def encode_default_value(nil, _depth) do
    []
  end

  def encode_default_value(default_value, depth) do
    [?\s, ?=, ?\s, Wormwood.SDL.Encoder.encode(default_value, depth)]
  end

  @spec encode_directives(term(), non_neg_integer()) :: iodata()
  def encode_directives(term, _depth) when is_nil(term) or term == [] do
    []
  end

  def encode_directives(list = [_ | _], depth) do
    Enum.map(list, &[?\s, Wormwood.SDL.Encoder.encode(&1, depth)])
  end

  @spec encode_description(term(), non_neg_integer()) :: iodata()
  def encode_description(nil, _depth) do
    []
  end

  def encode_description(description, depth) do
    indent = :binary.copy("  ", depth)
    [indent, OJSON.encode!(description), ?\n]
  end

  @spec encode_enum_values(term(), non_neg_integer()) :: iodata()
  def encode_enum_values(term, _depth) when is_nil(term) or term == [] do
    []
  end

  def encode_enum_values(list = [_ | _], depth) do
    indent = :binary.copy("  ", depth)
    [?\s, ?{, ?\n, Enum.map(list, &Wormwood.SDL.Encoder.encode(&1, depth + 1)), indent, ?}]
  end

  @spec encode_field_definitions(term(), non_neg_integer()) :: iodata()
  def encode_field_definitions(term, _depth) when is_nil(term) or term == [] do
    []
  end

  def encode_field_definitions(field_definitions, depth) do
    indent = :binary.copy("  ", depth)
    [?\s, ?{, ?\n, Enum.map(field_definitions, &Wormwood.SDL.Encoder.encode(&1, depth + 1)), indent, ?}]
  end

  @spec encode_interfaces(term(), non_neg_integer()) :: iodata()
  def encode_interfaces(term, _depth) when is_nil(term) or term == [] do
    []
  end

  def encode_interfaces(list = [_ | _], depth) do
    [[?\s, ?&, ?\s | head] | tail] = Enum.map(list, &[?\s, ?&, ?\s, Wormwood.SDL.Encoder.encode(&1, depth)])
    [" implements ", head | tail]
  end

  @spec encode_name(term()) :: iodata()
  def encode_name(nil) do
    []
  end

  def encode_name(name) do
    to_string(name)
  end

  @spec encode_selection_set(term(), non_neg_integer()) :: iodata()
  def encode_selection_set(term, _depth) when is_nil(term) or term == [] do
    []
  end

  def encode_selection_set(%{selections: []}, _depth) do
    []
  end

  def encode_selection_set(selection_set, depth) do
    [?\s | Wormwood.SDL.Encoder.encode(selection_set, depth)]
  end

  @spec encode_type_condition(term(), non_neg_integer()) :: iodata()
  def encode_type_condition(nil, _depth) do
    []
  end

  def encode_type_condition(type_condition, depth) do
    [" on " | Wormwood.SDL.Encoder.encode(type_condition, depth)]
  end

  @spec encode_union_types(term(), non_neg_integer()) :: iodata()
  def encode_union_types(term, _depth) when is_nil(term) or term == [] do
    []
  end

  def encode_union_types(list = [_ | _], depth) do
    [[?\s, ?|, ?\s | head] | tail] = Enum.map(list, &[?\s, ?|, ?\s, Wormwood.SDL.Encoder.encode(&1, depth)])
    [?\s, ?=, ?\s, head | tail]
  end

  def maybe_extend(description, label, depth) when is_integer(depth) and depth >= 0 do
    indent = :binary.copy("  ", depth)

    header = [
      encode_description(description, depth),
      indent,
      label
    ]

    {header, depth}
  end

  def maybe_extend(description, label, {:extend, prefix, depth}) when is_integer(depth) and depth >= 0 do
    indent = :binary.copy("  ", depth)

    header = [
      encode_description(description, depth),
      indent,
      prefix,
      label
    ]

    {header, depth}
  end
end
