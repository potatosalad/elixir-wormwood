defmodule Wormwood.Library.Validation.FragmentUntypedConflict do
  @moduledoc false

  alias Wormwood.Library.Validation.FragmentUntyped.AmbiguousFieldSelectionError, as: AmbiguousFieldSelectionError

  defmodule State do
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
    :ok =
      Enum.each(fragments, fn fragment = %Wormwood.Language.Fragment{} ->
        :ok = validate_flat_fragment!(library, fragment)
      end)

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
        state = validate_flat_selection_set!(State.new(state), selection_set)
        conflicts = State.conflicts(state)

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
    state = validate_flat_selection_set!(State.new(library), selection_set)
    conflicts = State.conflicts(state)

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
        State.put(state, field)

      fragment_spread = %Wormwood.Language.FragmentSpread{}, state ->
        validate_flat_fragment_spread!(%{state | mode: :fragment}, fragment_spread)

      inline_fragment = %Wormwood.Language.InlineFragment{}, state ->
        validate_flat_inline_fragment!(%{state | mode: :fragment}, inline_fragment)
    end)
  end
end
