defmodule Wormwood.SDL do
  def decode!(input) do
    source = prepare_source!(input)
    Wormwood.SDL.Decoder.parse!(source)
  end

  def decode(input) do
    source = prepare_source!(input)

    try do
      Wormwood.SDL.Decoder.parse!(source)
    catch
      :error, exception = %Wormwood.SDL.DecodeError{} ->
        {:error, exception}
    else
      document = %Wormwood.Language.Document{} ->
        {:ok, document}
    end
  end

  def encode(language) do
    Wormwood.SDL.Encoder.encode(language, %Wormwood.SDL.Encoder.Opts{depth: 0})
  end

  def encode(language, opts = %Wormwood.SDL.Encoder.Opts{}) do
    Wormwood.SDL.Encoder.encode(language, opts)
  end

  def encode(language, opts) when is_list(opts) or is_map(opts) do
    opts = %Wormwood.SDL.Encoder.Opts{} = Wormwood.SDL.Encoder.Opts.__struct__(opts)
    encode(language, opts)
  end

  def prepare_source!(input) when is_binary(input) do
    %Wormwood.Language.Source{body: input}
  end

  def prepare_source!(input) when is_list(input) do
    %Wormwood.Language.Source{body: :erlang.iolist_to_binary(input)}
  end

  def prepare_source!(source = %Wormwood.Language.Source{name: name, body: nil}) do
    body = File.read!(name)
    %{source | body: body}
  end

  def prepare_source!(source = %Wormwood.Language.Source{body: body}) when is_binary(body) do
    source
  end

  def roundtrip_test(document = %Wormwood.Language.Document{}) do
    doc1 = delete_all_loc(%{document | source: nil})
    doc2 = delete_all_loc(%{decode!(encode(doc1)) | source: nil})
    doc1 === doc2
  end

  def roundtrip_test(input) when is_binary(input) or is_list(input) do
    roundtrip_test(decode!(input))
  end

  @doc false
  defp delete_all_loc(map) when is_map(map) do
    map =
      if Map.has_key?(map, :loc) do
        Map.put(map, :loc, nil)
      else
        map
      end

    :maps.fold(&Map.put(&3, &1, delete_all_loc(&2)), Map.new(), map)
  end

  defp delete_all_loc(list) when is_list(list) do
    :lists.map(&delete_all_loc/1, list)
  end

  defp delete_all_loc(term) do
    term
  end
end
