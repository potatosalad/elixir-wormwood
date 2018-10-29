defmodule Mix.Tasks.Wormwood.Format do
  use Mix.Task

  @shortdoc "Formats the given GraphQL files/patterns"

  @moduledoc """
  Formats the given files and patterns.

      mix wormwood.format schema.graphql "priv/**/*.graphql"

  If any of the files is `-`, then the output is read from stdin
  and written to stdout.

  ## Task-specific options

    * `--check-formatted` - checks that the file is already formatted.
      This is useful in pre-commit hooks and CI scripts if you want to
      reject contributions with unformatted code. However keep in mind
      that the formatted output may differ between Elixir versions as
      improvements and fixes are applied to the formatter.

    * `--check-equivalent` - checks if the files after formatting have the
      same AST as before formatting. If the ASTs are not equivalent, it is
      a bug in the code formatter. This option is useful if you suspect you
      have ran into a formatter bug and you would like confirmation.

    * `--dry-run` - does not save files after formatting.

  If any of the `--check-*` flags are given and a check fails, the formatted
  contents won't be written to disk nor printed to standard output.

  ## When to format code

  We recommend developers to format code directly in their editors, either
  automatically when saving a file or via an explicit command or key binding. If
  such option is not yet available in your editor of choice, adding the required
  integration is usually a matter of invoking:

      cd $project && mix wormwood.format $file

  where `$file` refers to the current file and `$project` is the root of your
  project.

  It is also possible to format code across the whole project by passing a list
  of patterns and files to `mix wormwood.format`, as shown at the top of this task
  documentation.

  """

  @switches [
    check_equivalent: :boolean,
    check_formatted: :boolean,
    dry_run: :boolean
  ]

  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches)

    args
    |> expand_args(opts)
    |> Task.async_stream(&format_file(&1, opts), ordered: false, timeout: 30000)
    |> Enum.reduce({[], [], []}, &collect_status/2)
    |> check!()
  end

  @doc false
  defp expand_args([], _opts) do
    Mix.raise("Expected one or more files/patterns to be given to mix wormwood.format")
  end

  defp expand_args(files_and_patterns, opts) do
    files =
      for file_or_pattern <- files_and_patterns,
          file <- stdin_or_wildcard(file_or_pattern),
          uniq: true,
          do: file

    if files == [] do
      Mix.raise(
        "Could not find a file to format. The files/patterns given to command line " <>
          "did not point to any existing file. Got: #{inspect(files_and_patterns)}"
      )
    end

    for file <- files do
      if file == :stdin do
        {file, opts}
      else
        # split = file |> Path.relative_to_cwd() |> Path.split()
        {file, opts}
      end
    end
  end

  @doc false
  defp stdin_or_wildcard("-"), do: [:stdin]
  defp stdin_or_wildcard(path), do: path |> Path.expand() |> Path.wildcard(match_dot: true)

  @doc false
  defp read_file(:stdin) do
    {IO.stream(:stdio, :line) |> Enum.to_list() |> IO.iodata_to_binary(), file: "stdin"}
  end

  defp read_file(file) do
    {File.read!(file), file: file}
  end

  @doc false
  defp format_file({file, _formatter_opts}, task_opts) do
    {input, _extra_opts} = read_file(file)
    output = IO.iodata_to_binary(Wormwood.GraphQL.format_string!(input))

    check_equivalent? = Keyword.get(task_opts, :check_equivalent, false)
    check_formatted? = Keyword.get(task_opts, :check_formatted, false)
    dry_run? = Keyword.get(task_opts, :dry_run, false)

    cond do
      check_equivalent? and not equivalent?(input, output) ->
        {:not_equivalent, file}

      check_formatted? ->
        if input == output, do: :ok, else: {:not_formatted, file}

      dry_run? ->
        :ok

      true ->
        write_or_print(file, input, output)
    end
  rescue
    exception ->
      {:exit, file, exception, __STACKTRACE__}
  end

  @doc false
  defp write_or_print(file, input, output) do
    cond do
      file == :stdin -> IO.write(output)
      input == output -> :ok
      true -> File.write!(file, output)
    end

    :ok
  end

  @doc false
  defp collect_status({:ok, :ok}, acc), do: acc

  defp collect_status({:ok, {:exit, _, _, _} = exit}, {exits, not_equivalent, not_formatted}) do
    {[exit | exits], not_equivalent, not_formatted}
  end

  defp collect_status({:ok, {:not_equivalent, file}}, {exits, not_equivalent, not_formatted}) do
    {exits, [file | not_equivalent], not_formatted}
  end

  defp collect_status({:ok, {:not_formatted, file}}, {exits, not_equivalent, not_formatted}) do
    {exits, not_equivalent, [file | not_formatted]}
  end

  @doc false
  defp check!({[], [], []}) do
    :ok
  end

  defp check!({[{:exit, file, exception, stacktrace} | _], _not_equivalent, _not_formatted}) do
    Mix.shell().error("mix wormwood.format failed for file: #{Path.relative_to_cwd(file)}")
    reraise exception, stacktrace
  end

  defp check!({_exits, [_ | _] = not_equivalent, _not_formatted}) do
    Mix.raise("""
    mix wormwood.format failed due to --check-equivalent.
    The following files were not equivalent:

    #{to_bullet_list(not_equivalent)}

    Please report this bug with the input files at github.com/elixir-lang/elixir/issues
    """)
  end

  defp check!({_exits, _not_equivalent, [_ | _] = not_formatted}) do
    Mix.raise("""
    mix wormwood.format failed due to --check-formatted.
    The following files were not formatted:

    #{to_bullet_list(not_formatted)}
    """)
  end

  @doc false
  defp to_bullet_list(files) do
    Enum.map_join(files, "\n", &"  * #{&1}")
  end

  @doc false
  defp equivalent?(input, output) do
    strip_locations = fn
      node = %{loc: _, source: _}, _parent, _path, :ok ->
        node = %{node | loc: nil, source: nil}
        {:cont, :ok, {:update, node}}

      node = %{loc: _}, _parent, _path, :ok ->
        node = %{node | loc: nil}
        {:cont, :ok, {:update, node}}

      _node, _parent, _path, :ok ->
        :cont
    end

    {input_sdl, :ok} = Wormwood.Traversal.reduce(Wormwood.SDL.decode!(input), :ok, strip_locations)
    {output_sdl, :ok} = Wormwood.Traversal.reduce(Wormwood.SDL.decode!(output), :ok, strip_locations)
    input_sdl === output_sdl
  end
end
