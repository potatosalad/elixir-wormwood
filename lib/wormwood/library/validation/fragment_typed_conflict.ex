# defmodule Wormwood.Library.Validation.FragmentTypedConflict do
#   @moduledoc false

#   alias Wormwood.Library.Validation.FragmentTyped.AmbiguousFieldSelectionError, as: AmbiguousFieldSelectionError
#   alias Wormwood.Library.Validation.FragmentTyped.FieldSelectionError, as: FieldSelectionError
#   alias Wormwood.Library.Validation.FragmentTyped.FragmentTypeError, as: FragmentTypeError

#   defmodule State do
#     @moduledoc false
#     @enforce_keys [:library, :definitions, :selections]
#     defstruct [:library, :definitions, :selections, store: Map.new()]

#     def new(state = %__MODULE__{}) do
#       %__MODULE__{state | store: Map.new()}
#     end

#     def conflicts(%__MODULE__{store: store}) do
#       # IO.inspect(store)
#       Enum.reduce(store, Map.new(), fn {definition_key, possible_conflicts}, acc ->
#         Enum.reduce(possible_conflicts, acc, fn {field_key, fields}, acc ->
#           if length(fields) > 1 do
#             Map.update(acc, definition_key, %{field_key => fields}, &Map.put(&1, field_key, fields))
#           else
#             acc
#           end
#         end)
#       end)
#     end

#     def push(state = %__MODULE__{definitions: definitions, selections: selections}, definition, selection) do
#       definitions = [definition | definitions]
#       selections = [selection | selections]
#       %__MODULE__{state | definitions: definitions, selections: selections}
#     end

#     def put(state = %__MODULE__{store: store}, field) do
#       definition_keys = definition_keys!(state, field)
#       field_key = field_key!(field)
#       store = Enum.reduce(definition_keys, store, fn
#         definition_key, acc ->
#           Map.update(acc, definition_key, %{field_key => [field]}, fn fields ->
#             Map.update(fields, field_key, [field], &[field | &1])
#           end)
#       end)
#       state = %__MODULE__{state | store: store}
#       state
#     end

#     @doc false
#     defp field_key!(%{alias: nil, name: field_name}) when is_binary(field_name) and byte_size(field_name) > 0 do
#       field_name
#     end

#     defp field_key!(%{alias: field_alias, name: _}) when is_binary(field_alias) and byte_size(field_alias) > 0 do
#       field_alias
#     end

#     @doc false
#     defp definition_keys!(%__MODULE__{library: library, definitions: [definition = %{__struct__: module} | _]}, %{name: field_name}) when module in [Wormwood.Language.InterfaceTypeDefinition, Wormwood.Language.ObjectTypeDefinition] do
#       related_objects = Wormwood.Library.Validation.Typed.flatten_related_objects!(library, definition)
#       Enum.map(related_objects, fn %{name: name} -> name end)
#       # IO.inspect(related_objects)
#       # Enum.reduce(related_objects, [], fn
#       #   %{__struct__: module, name: name, fields: field_definitions = [_ | _]}, acc when module in [Wormwood.Language.InterfaceTypeDefinition, Wormwood.Language.ObjectTypeDefinition] ->
#       #     Enum.reduce(field_definitions, acc, fn
#       #       %Wormwood.Language.FieldDefinition{name: field_definition_name}, acc ->
#       #         if field_definition_name === field_name do
#       #           [name | acc]
#       #         else
#       #           acc
#       #         end
#       #     end)
#       # end)
#     end

#     # defp definition_keys!(%__MODULE__{definitions: [%Wormwood.Language.InterfaceTypeDefinition{name: name} | _]}, _field) do
#     #   [name]
#     # end

#     # defp definition_keys!(%__MODULE__{library: library, definitions: [object_type_definition = %Wormwood.Language.ObjectTypeDefinition{name: object_type_name} | _]}, %{name: field_name}) do
#     #   related_objects = Wormwood.Library.Validation.Typed.flatten_related_objects!(library, object_type_definition)
#     #   # IO.inspect(interfaces, label: "interfaces")
#     #   Enum.reduce(interfaces, [object_type_name], fn
#     #     %Wormwood.Language.InterfaceTypeDefinition{name: interface_name, fields: field_definitions = [_ | _]}, acc ->
#     #       Enum.reduce(field_definitions, acc, fn
#     #         %Wormwood.Language.FieldDefinition{name: field_definition_name}, acc ->
#     #           if field_definition_name === field_name do
#     #             [interface_name | acc]
#     #           else
#     #             acc
#     #           end
#     #       end)
#     #   end)
#     # end
#   end

#   @doc false
#   def validate!(library = %Wormwood.Library{}, fragments = [_ | _]) do
#     :ok =
#       Enum.each(fragments, fn fragment = %Wormwood.Language.Fragment{} ->
#         :ok = validate_flat_fragment!(library, fragment)
#       end)

#     :ok
#   end

#   @doc false
#   def validate_flat_field!(state = %{library: library}, field_definition = %Wormwood.Language.FieldDefinition{type: type_reference}, field = %Wormwood.Language.Field{selection_set: selection_set}) do
#     definition = Wormwood.Library.Validation.Typed.resolve!(library, type_reference)
#     case selection_set do
#       nil ->
#         :ok

#       %Wormwood.Language.SelectionSet{selections: []} ->
#         :ok

#       %Wormwood.Language.SelectionSet{selections: [_ | _]} ->
#         state = validate_flat_selection_set!(State.new(State.push(state, definition, field)), selection_set)
#         conflicts = State.conflicts(state)

#         # if map_size(conflicts) === 0 do
#         #   :ok
#         # else
#         #   IO.inspect(conflicts)
#         #   raise("there were field conflicts")
#         # end

#         errors =
#           Enum.reduce(conflicts, [], fn {type_name, field_conflicts}, acc ->
#             {:ok, definition} = Wormwood.Library.Validation.Typed.validate_type_reference!(library, %Wormwood.Language.NamedType{name: type_name})
#             Enum.reduce(field_conflicts, acc, fn {_, selections}, acc ->
#               Enum.reduce(selections, acc, fn selection, acc ->
#                 error = AmbiguousFieldSelectionError.exception(definition: definition, selection: selection)
#                 [error | acc]
#               end)
#             end)
#           end)

#         if errors === [] do
#           :ok
#         else
#           # import Wormwood.Library.Errors, only: [format_sdl!: 2]
#           # conflicting_names = Map.keys(conflicts) |> Enum.sort() |> Enum.map(&"  - #{inspect(&1)}") |> Enum.join("\n")
#           # dumped_field = format_sdl!(field, 2)

#           raise(Wormwood.Library.CompilationError, errors: errors)

#           # raise(Wormwood.Library.CompilationError,
#           #   errors: errors,
#           #   reason: """
#           #   Field selections of the same name MUST NOT cross the object and fragment boundary.

#           #   Ambiguous names:

#           #   #{conflicting_names}

#           #   Field:

#           #     #{dumped_field}

#           #   Either remove fragment or object field selections.
#           #   """
#           # )
#         end
#     end
#   end

#   @doc false
#   def validate_flat_fragment!(library, fragment = %Wormwood.Language.Fragment{type_condition: type_condition, selection_set: selection_set}) do
#     {:ok, definition} = Wormwood.Library.Validation.Typed.validate_type_reference!(library, type_condition)

#     case definition do
#       %{__struct__: module} when module in [Wormwood.Language.InterfaceTypeDefinition, Wormwood.Language.ObjectTypeDefinition] ->
#         state = %State{library: library, definitions: [definition], selections: [fragment]}
#         state = validate_flat_selection_set!(state, selection_set)
#         conflicts = State.conflicts(state)

#         errors =
#           Enum.reduce(conflicts, [], fn {type_name, field_conflicts}, acc ->
#             {:ok, definition} = Wormwood.Library.Validation.Typed.validate_type_reference!(library, %Wormwood.Language.NamedType{name: type_name})
#             Enum.reduce(field_conflicts, acc, fn {_, selections}, acc ->
#               Enum.reduce(selections, acc, fn selection, acc ->
#                 error = AmbiguousFieldSelectionError.exception(definition: definition, selection: selection)
#                 [error | acc]
#               end)
#             end)
#           end)

#         if errors === [] do
#           :ok
#         else
#           raise(Wormwood.Library.CompilationError, errors: errors)
#         end

#         # if map_size(conflicts) === 0 do
#         #   :ok
#         # else
#         #   IO.inspect(conflicts)
#         #   raise("there were fragment conflicts")
#         # end

#         # errors =
#         #   Enum.flat_map(conflicts, fn {_, fields} ->
#         #     Enum.map(fields, fn node ->
#         #       AmbiguousFieldSelectionError.exception(field: node)
#         #     end)
#         #   end)

#         # if errors === [] do
#         #   :ok
#         # else
#         #   import Wormwood.Library.Errors, only: [format_sdl!: 2]
#         #   conflicting_names = Map.keys(conflicts) |> Enum.sort() |> Enum.map(&"  - #{inspect(&1)}") |> Enum.join("\n")
#         #   dumped_fragment = format_sdl!(fragment, 2)

#         #   raise(Wormwood.Library.CompilationError,
#         #     errors: errors,
#         #     reason: """
#         #     Field selections of the same name MUST NOT cross the object and fragment boundary.

#         #     Ambiguous names:

#         #     #{conflicting_names}

#         #     Fragment:

#         #       #{dumped_fragment}

#         #     Either remove fragment or object field selections.
#         #     """
#         #   )
#         # end

#       %{__struct__: _} ->
#         errors = [FragmentTypeError.exception(definition: definition, selection: fragment)]
#         raise(Wormwood.Library.CompilationError, errors: errors)
#     end
#   end

#   @doc false
#   def validate_flat_fragment_spread!(state = %{library: library = %{fragments: fragments}}, %Wormwood.Language.FragmentSpread{name: name}) do
#     fragment = %Wormwood.Language.Fragment{type_condition: type_condition, selection_set: selection_set} = Map.fetch!(fragments, name)
#     {:ok, definition} = Wormwood.Library.Validation.Typed.validate_type_reference!(library, type_condition)
#     validate_flat_selection_set!(State.push(state, definition, fragment), selection_set)
#   end

#   @doc false
#   def validate_flat_inline_fragment!(state = %{library: library}, inline_fragment = %Wormwood.Language.InlineFragment{type_condition: type_condition, selection_set: selection_set}) do
#     {:ok, definition} = Wormwood.Library.Validation.Typed.validate_type_reference!(library, type_condition)
#     validate_flat_selection_set!(State.push(state, definition, inline_fragment), selection_set)
#   end

#   @doc false
#   def validate_flat_selection_set!(state = %{definitions: [definition | _]}, %Wormwood.Language.SelectionSet{selections: selections = [_ | _]}) do
#     Enum.reduce(selections, state, fn
#       field = %Wormwood.Language.Field{name: "__typename"}, state ->
#         field_definition = %Wormwood.Language.FieldDefinition{name: "__typename", type: %Wormwood.Language.NonNullType{type: %Wormwood.Language.NamedType{name: "String"}}}
#         :ok = validate_flat_field!(state, field_definition, field)
#         State.put(state, field)

#       field = %Wormwood.Language.Field{name: field_name}, state ->
#         field_definitions =
#           case definition do
#             %Wormwood.Language.InterfaceTypeDefinition{fields: field_definitions} ->
#               field_definitions

#             %Wormwood.Language.ObjectTypeDefinition{fields: field_definitions} ->
#               field_definitions
#           end

#         field_definition = Enum.find(field_definitions, fn %{name: n} -> n === field_name end)

#         if not is_nil(field_definition) do
#           :ok = validate_flat_field!(state, field_definition, field)
#           State.put(state, field)
#         else
#           errors = [FieldSelectionError.exception(definition: definition, selection: field)]
#           raise(Wormwood.Library.CompilationError, errors: errors)
#         end

#       fragment_spread = %Wormwood.Language.FragmentSpread{}, state ->
#         validate_flat_fragment_spread!(state, fragment_spread)

#       inline_fragment = %Wormwood.Language.InlineFragment{}, state ->
#         validate_flat_inline_fragment!(state, inline_fragment)
#     end)
#   end
# end
