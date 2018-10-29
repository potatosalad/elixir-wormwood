defmodule Wormwood.Library.Validation.FragmentUntyped do
  @moduledoc false

  defmodule AmbiguousFieldSelectionError do
    @moduledoc false
    defexception [:field]

    import Wormwood.Library.Errors, only: [format_loc!: 1]

    def message(%__MODULE__{field: node = %{name: name}}) do
      "Ambiguous field selection error for #{inspect(name)} in #{format_loc!(node)}"
    end
  end

  defmodule CyclicFragmentSpreadError do
    @moduledoc false
    defexception [:fragment, :cycle]

    import Wormwood.Library.Errors, only: [format_loc!: 1]

    def message(%__MODULE__{fragment: node = %{name: fragment_name}, cycle: cycle}) do
      "Cyclic fragment spread detected for #{inspect(fragment_name)} as #{inspect(cycle)} in #{format_loc!(node)}"
    end
  end

  defmodule DuplicateArgumentError do
    @moduledoc false
    defexception [:parent, :argument]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_mod!: 1]

    def message(%__MODULE__{parent: parent = %{name: parent_name}, argument: node = %{name: argument_name}}) do
      subject = Wormwood.Language.subject(parent)
      "Duplicate argument found for #{inspect(argument_name)} on #{subject} #{inspect(parent_name)} in #{format_loc!(node)}"
    end
  end

  defmodule DuplicateFieldError do
    @moduledoc false
    defexception [:parent, :field]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_mod!: 1]

    def message(%__MODULE__{parent: parent = %{name: parent_name}, field: node = %{alias: field_alias, name: field_name}}) do
      subject = Wormwood.Language.subject(parent)

      if is_nil(field_alias) or field_alias === <<>> do
        "Duplicate field found for #{inspect(field_name)} on #{subject} #{inspect(parent_name)} in #{format_loc!(node)}"
      else
        "Duplicate field found for #{inspect(field_name)} as #{inspect(field_alias)} on #{subject} #{inspect(parent_name)} in #{
          format_loc!(node)
        }"
      end
    end
  end

  defmodule TypenameRequiredError do
    @moduledoc false
    defexception [:node]

    import Wormwood.Library.Errors, only: [format_loc!: 1]

    def message(%__MODULE__{node: node = %{name: name}}) do
      "Required field selection \"__typename\" missing for #{inspect(name)} in #{format_loc!(node)}"
    end
  end

  defmodule UndefinedFragmentSpreadError do
    @moduledoc false
    defexception [:node]

    import Wormwood.Library.Errors, only: [format_loc!: 1, format_mod!: 1]

    def message(%__MODULE__{node: node = %{name: name}}) do
      "Undefined fragment spread found for #{inspect(name)} of #{format_mod!(node)} in #{format_loc!(node)}"
    end
  end

  defmodule FlatState do
    @moduledoc false
    @enforce_keys [:library]
    defstruct [:library, mode: :field, fields: Map.new(), fragments: Map.new()]

    def new(library = %Wormwood.Library{}) do
      %__MODULE__{library: library}
    end

    def new(%__MODULE__{library: library = %Wormwood.Library{}}) do
      new(library)
    end

    def conflicts(%__MODULE__{fields: fields, fragments: fragments}) do
      Enum.reduce(fields, Map.new(), fn {key, list1}, acc ->
        case Map.fetch(fragments, key) do
          {:ok, list2} ->
            Map.put(acc, key, list1 ++ list2)

          :error ->
            acc
        end
      end)
    end

    def put(state = %__MODULE__{mode: :field, fields: fields}, field) do
      fields = Map.update(fields, field_key!(field), [field], &[field | &1])
      state = %__MODULE__{state | fields: fields}
      state
    end

    def put(state = %__MODULE__{mode: :fragment, fragments: fragments}, field) do
      fragments = Map.update(fragments, field_key!(field), [field], &[field | &1])
      state = %__MODULE__{state | fragments: fragments}
      state
    end

    @doc false
    defp field_key!(%{alias: nil, name: field_name}) when is_binary(field_name) and byte_size(field_name) > 0 do
      field_name
    end

    defp field_key!(%{alias: field_alias, name: _}) when is_binary(field_alias) and byte_size(field_alias) > 0 do
      field_alias
    end
  end

  @doc false
  def validate!(library = %Wormwood.Library{}, fragments = [_ | _]) do
    graph = :digraph.new([:cyclic])

    {cycle_count, errors} =
      try do
        :ok =
          Enum.each(fragments, fn fragment = %Wormwood.Language.Fragment{} ->
            :ok = validate_fragment!(library, graph, fragment)
          end)

        Enum.reduce(fragments, {0, []}, fn fragment = %{name: name}, {count, errs} ->
          case :digraph.get_cycle(graph, name) do
            cycle = [_ | _] ->
              error = CyclicFragmentSpreadError.exception(fragment: fragment, cycle: cycle)
              {count + 1, [error | errs]}

            false ->
              {count, errs}
          end
        end)
      after
        :digraph.delete(graph)
      end

    if cycle_count === 0 and errors === [] do
      :ok =
        Enum.each(fragments, fn fragment = %Wormwood.Language.Fragment{} ->
          :ok = validate_flat_fragment!(library, fragment)
        end)

      :ok
    else
      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        Fragment spreads must not form cycles, but #{cycle_count} cyclic fragment spreads were found.

        This module and/or its imported GraphQL is causing this error: #{inspect(library.module)}
        """
      )
    end
  end

  @doc false
  def validate_arguments!(_library, _parent, arguments) when is_nil(arguments) or arguments === [] do
    :ok
  end

  def validate_arguments!(library, parent, arguments = [_ | _]) do
    possible_duplicates =
      Enum.reduce(arguments, Map.new(), fn argument = %{name: name}, acc ->
        Map.update(acc, name, [argument], &[argument | &1])
      end)

    duplicates = Enum.reject(possible_duplicates, fn {_, nodes} -> length(nodes) === 1 end)

    if duplicates === [] do
      :ok
    else
      {duplicate_count, errors} =
        Enum.reduce(duplicates, {0, []}, fn {_, dups}, acc ->
          Enum.reduce(dups, acc, fn argument = %{__struct__: _}, {count, errs} ->
            error = DuplicateArgumentError.exception(parent: parent, argument: argument)
            {count + 1, [error | errs]}
          end)
        end)

      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        Arguments must be unique by name, but #{duplicate_count} duplicates were found.

        This module and/or its imported GraphQL is causing this error: #{inspect(library.module)}
        """
      )
    end
  end

  @doc false
  def validate_field!(library, parents, field = %Wormwood.Language.Field{arguments: arguments, selection_set: selection_set}) do
    :ok = validate_arguments!(library, field, arguments)

    :ok =
      case selection_set do
        nil ->
          :ok

        %Wormwood.Language.SelectionSet{selections: []} ->
          :ok

        %Wormwood.Language.SelectionSet{selections: [_ | _]} ->
          :ok = validate_selection_set!(library, [field | parents], selection_set)
          validate_typename_required!(library, [field | parents], selection_set)
      end

    :ok
  end

  @doc false
  def validate_flat_field!(state, field = %Wormwood.Language.Field{selection_set: selection_set}) do
    case selection_set do
      nil ->
        :ok

      %Wormwood.Language.SelectionSet{selections: []} ->
        :ok

      %Wormwood.Language.SelectionSet{selections: [_ | _]} ->
        state = validate_flat_selection_set!(FlatState.new(state), selection_set)
        conflicts = FlatState.conflicts(state)

        errors =
          Enum.flat_map(conflicts, fn {_, fields} ->
            Enum.map(fields, fn node ->
              AmbiguousFieldSelectionError.exception(field: node)
            end)
          end)

        if errors === [] do
          :ok
        else
          import Wormwood.Library.Errors, only: [format_sdl!: 2]
          conflicting_names = Map.keys(conflicts) |> Enum.sort() |> Enum.map(&"  - #{inspect(&1)}") |> Enum.join("\n")
          dumped_field = format_sdl!(field, 2)

          raise(Wormwood.Library.CompilationError,
            errors: errors,
            reason: """
            Field selections of the same name MUST NOT cross the object and fragment boundary.

            Ambiguous names:

            #{conflicting_names}

            Field:

              #{dumped_field}

            Either remove fragment or object field selections.
            """
          )
        end
    end
  end

  @doc false
  def validate_flat_fragment!(library, fragment = %Wormwood.Language.Fragment{selection_set: selection_set}) do
    state = validate_flat_selection_set!(FlatState.new(library), selection_set)
    conflicts = FlatState.conflicts(state)

    errors =
      Enum.flat_map(conflicts, fn {_, fields} ->
        Enum.map(fields, fn node ->
          AmbiguousFieldSelectionError.exception(field: node)
        end)
      end)

    if errors === [] do
      :ok
    else
      import Wormwood.Library.Errors, only: [format_sdl!: 2]
      conflicting_names = Map.keys(conflicts) |> Enum.sort() |> Enum.map(&"  - #{inspect(&1)}") |> Enum.join("\n")
      dumped_fragment = format_sdl!(fragment, 2)

      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        Field selections of the same name MUST NOT cross the object and fragment boundary.

        Ambiguous names:

        #{conflicting_names}

        Fragment:

          #{dumped_fragment}

        Either remove fragment or object field selections.
        """
      )
    end
  end

  @doc false
  def validate_flat_fragment_spread!(state = %{library: %{fragments: fragments}}, %Wormwood.Language.FragmentSpread{name: name}) do
    %Wormwood.Language.Fragment{selection_set: selection_set} = Map.fetch!(fragments, name)
    validate_flat_selection_set!(state, selection_set)
  end

  @doc false
  def validate_flat_inline_fragment!(state, %Wormwood.Language.InlineFragment{selection_set: selection_set}) do
    validate_flat_selection_set!(state, selection_set)
  end

  @doc false
  def validate_flat_selection_set!(state, %Wormwood.Language.SelectionSet{selections: selections = [_ | _]}) do
    Enum.reduce(selections, state, fn
      field = %Wormwood.Language.Field{}, state ->
        :ok = validate_flat_field!(state, field)
        FlatState.put(state, field)

      fragment_spread = %Wormwood.Language.FragmentSpread{}, state ->
        validate_flat_fragment_spread!(%{state | mode: :fragment}, fragment_spread)

      inline_fragment = %Wormwood.Language.InlineFragment{}, state ->
        validate_flat_inline_fragment!(%{state | mode: :fragment}, inline_fragment)
    end)
  end

  @doc false
  def validate_fragment!(library, graph, fragment = %Wormwood.Language.Fragment{name: fragment_name, selection_set: selection_set}) do
    :ok = validate_selection_set!(library, [fragment], selection_set)
    _ = :digraph.add_vertex(graph, fragment_name)

    {_, :ok} =
      Wormwood.Traversal.reduce(fragment, :ok, fn
        %Wormwood.Language.FragmentSpread{name: fragment_spread_name}, _parent, _path, :ok ->
          _ = :digraph.add_vertex(graph, fragment_spread_name)
          _ = :digraph.add_edge(graph, fragment_name, fragment_spread_name)
          :cont

        _node, _parent, _path, :ok ->
          :cont
      end)

    :ok
  end

  @doc false
  def validate_fragment_spread!(
        library = %{fragments: fragments},
        _parents,
        fragment_spread = %Wormwood.Language.FragmentSpread{name: name}
      ) do
    if Map.has_key?(fragments, name) do
      :ok
    else
      errors = [UndefinedFragmentSpreadError.exception(node: fragment_spread)]

      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        All fragment spreads must be defined, but 1 undefined fragment spread was found.

        This module and/or its imported GraphQL is causing this error: #{inspect(library.module)}
        """
      )
    end
  end

  @doc false
  def validate_inline_fragment!(library, parents, inline_fragment = %Wormwood.Language.InlineFragment{selection_set: selection_set}) do
    :ok = validate_selection_set!(library, [inline_fragment | parents], selection_set)
    :ok
  end

  @doc false
  def validate_selection_set!(library, parents = [parent | _], %Wormwood.Language.SelectionSet{selections: selections = [_ | _]}) do
    possible_duplicates =
      Enum.reduce(selections, Map.new(), fn
        field = %Wormwood.Language.Field{alias: alias, name: name}, acc ->
          :ok = validate_field!(library, parents, field)

          key =
            if is_nil(alias) do
              name
            else
              alias
            end

          Map.update(acc, key, [field], &[field | &1])

        fragment_spread = %Wormwood.Language.FragmentSpread{}, acc ->
          :ok = validate_fragment_spread!(library, parents, fragment_spread)
          acc

        inline_fragment = %Wormwood.Language.InlineFragment{}, acc ->
          :ok = validate_inline_fragment!(library, parents, inline_fragment)
          acc
      end)

    duplicates = Enum.reject(possible_duplicates, fn {_, nodes} -> length(nodes) === 1 end)

    if duplicates === [] do
      :ok
    else
      {duplicate_count, errors} =
        Enum.reduce(duplicates, {0, []}, fn {_, dups}, acc ->
          Enum.reduce(dups, acc, fn field = %{__struct__: _}, {count, errs} ->
            error = DuplicateFieldError.exception(parent: parent, field: field)
            {count + 1, [error | errs]}
          end)
        end)

      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        Field selections must be unique by name, but #{duplicate_count} duplicates were found.

        This module and/or its imported GraphQL is causing this error: #{inspect(library.module)}
        """
      )
    end
  end

  @doc false
  def validate_typename_required!(library, _parents = [parent | _], %Wormwood.Language.SelectionSet{
        selections: selections = [_ | _]
      }) do
    has_typename =
      Enum.any?(selections, fn
        %Wormwood.Language.Field{alias: nil, name: "__typename"} -> true
        _ -> false
      end)

    if has_typename do
      :ok
    else
      errors = [TypenameRequiredError.exception(node: parent)]
      fixed_field = add_typename_to_fields!(parent)
      fixed_example = :erlang.iolist_to_binary(Wormwood.SDL.encode(fixed_field))
      fixed_example = fixed_example |> :binary.split(<<?\n>>, [:global]) |> Enum.map(&("  " <> &1)) |> Enum.join(<<?\n>>)

      raise(Wormwood.Library.CompilationError,
        errors: errors,
        reason: """
        Field selection "__typename" MUST be added to all field selections for object types.

        For example:

        #{fixed_example}

        This module and/or its imported GraphQL is causing this error: #{inspect(library.module)}
        """
      )
    end
  end

  @doc false
  defp add_typename_to_fields!(field = %Wormwood.Language.Field{}) do
    check_for_typename = fn
      %Wormwood.Language.Field{alias: nil, name: "__typename"} -> true
      _ -> false
    end

    {updated_field, :ok} =
      Wormwood.Traversal.reduce(field, :ok, fn
        node = %Wormwood.Language.SelectionSet{selections: selections = [_ | _]}, %Wormwood.Language.Field{}, _path, :ok ->
          if Enum.any?(selections, check_for_typename) do
            :cont
          else
            selections = [%Wormwood.Language.Field{name: "__typename"} | selections]
            node = %{node | selections: selections}
            {:cont, :ok, {:update, node}}
          end

        _node, _parent, _path, :ok ->
          :cont
      end)

    updated_field
  end
end
