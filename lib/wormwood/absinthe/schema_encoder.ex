defmodule Wormwood.Absinthe.SchemaEncoder do
  def encode!(schema, _opts \\ []) do
    do_encode(schema)
  end

  @doc false
  defp do_encode(%{data: schema = %{"__schema" => _}}) do
    do_encode(schema)
  end

  defp do_encode(%{"data" => schema = %{"__schema" => _}}) do
    do_encode(schema)
  end

  defp do_encode(schema = %{"__schema" => _}) do
    document = Wormwood.Schema.JSON.load!(schema)
    document = Wormwood.Schema.normalize!(document)
    Wormwood.SDL.encode(document)
  end
end
