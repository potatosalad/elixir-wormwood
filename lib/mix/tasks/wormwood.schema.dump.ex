defmodule Mix.Tasks.Wormwood.Schema.Dump do
  require Logger
  use Mix.Task
  import Mix.Generator

  @shortdoc "Generate a schema.graphql file for an Absinthe schema"

  @default_filename "./schema.graphql"

  @moduledoc """
  Generate a schema.graphql file

  ## Usage

      wormwood.schema.dump [FILENAME] [OPTIONS]

    The `--schema-codec` module to be used needs to be included in your `mix.exs` dependencies.

  ## Options

  * `--schema` - The name of the `Absinthe.Schema` module defining the schema to be generated.
     Default: As [configured](https://hexdocs.pm/mix/Mix.Config.html) for `:absinthe` `:schema`
  * `--schema-codec` - Codec to use to generate the GraphQL file (see [Custom Codecs](#module-custom-codecs)).
     Default: `Wormwood.Absinthe.SchemaEncoder`

  ## Examples

  Write to default path `#{@default_filename}` using the `:schema` configured for the `:absinthe` application:

      $ mix wormwood.schema.dump

  Write to default path `#{@default_filename}` using the `MySchema` schema:

      $ mix wormwood.schema.dump --schema MySchema

  Write to path `/path/to/schema.graphql` using the `MySchema` schema:

      $ mix wormwood.schema.dump --schema MySchema /path/to/schema.graphql

  Write to default path `#{@default_filename}` using the `MySchema` schema and a custom schema codec, `MyCodec`:

      $ mix wormwood.schema.dump --schema MySchema --schema-codec MyCodec


  ## Custom Codecs

  Any module that provides `encode!/2` can be used as a custom codec:

      encode!(value, options)

  * `value` will be provided as a Map containing the generated schema.
  * `options` will be an empty keyword list.

  The function should return a string to be written to the output file.

  """

  defmodule Options do
    @moduledoc false

    defstruct filename: nil, schema: nil, schema_codec: nil

    @type t() :: %__MODULE__{
            filename: String.t(),
            schema: module(),
            schema_codec: module()
          }
  end

  @doc "Callback implementation for `Mix.Task.run/1`, which receives a list of command-line args."
  @spec run(argv :: [binary()]) :: any()
  def run(argv) do
    Application.ensure_all_started(:absinthe)

    Mix.Task.run("loadpaths", argv)
    Mix.Project.compile(argv)

    opts = parse_options(argv)

    case generate_schema(opts) do
      {:ok, content} -> write_schema(content, opts.filename)
      {:error, error} -> raise error
    end
  end

  @doc false
  @spec generate_schema(Options.t()) :: String.t()
  def generate_schema(%Options{
        schema: schema,
        schema_codec: schema_codec
      }) do
    with {:ok, result} <- apply(Absinthe.Schema, :introspect, [schema]),
         content <- schema_codec.encode!(result, []) do
      {:ok, content}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, error}
    end
  end

  @doc false
  @spec parse_options([String.t()]) :: Options.t()
  def parse_options(argv) do
    parse_options = [strict: [schema: :string, schema_codec: :string]]
    {opts, args, _} = OptionParser.parse(argv, parse_options)

    %Options{
      filename: args |> List.first() || @default_filename,
      schema: find_schema(opts),
      schema_codec: schema_codec_as_atom(opts)
    }
  end

  defp schema_codec_as_atom(opts) do
    opts
    |> Keyword.fetch(:schema_codec)
    |> case do
      {:ok, codec} -> Module.concat([codec])
      _ -> Wormwood.Absinthe.SchemaEncoder
    end
  end

  defp find_schema(opts) do
    case Keyword.get(opts, :schema, Application.get_env(:absinthe, :schema)) do
      nil ->
        raise "No --schema given or :schema configured for the :absinthe application"

      value ->
        [value] |> Module.safe_concat()
    end
  end

  defp write_schema(content, filename) do
    create_directory(Path.dirname(filename))
    create_file(filename, content, force: true)
  end
end
