defprotocol Wormwood.Traversal.Node do
  @moduledoc false

  @type t() :: term()

  @fallback_to_any true

  @spec children(any()) :: [any()]
  def children(node)
end

defimpl Wormwood.Traversal.Node, for: Any do
  def children(_node) do
    []
  end
end

defimpl Wormwood.Traversal.Node,
  for: [
    Wormwood.Language.Argument,
    Wormwood.Language.EnumValue,
    Wormwood.Language.FloatValue,
    Wormwood.Language.IntValue,
    Wormwood.Language.ObjectField,
    Wormwood.Language.StringValue
  ] do
  def children(%@for{value: value}) do
    case value do
      %{__struct__: _} ->
        [{[:value], value}]

      _ ->
        []
    end
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.Directive do
  def children(%@for{arguments: arguments}) do
    Wormwood.Traversal.maybe_compact_children([{[:arguments], arguments}])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.DirectiveDefinition do
  def children(%@for{arguments: arguments, directives: directives, locations: locations}) do
    Wormwood.Traversal.maybe_compact_children([
      {[:arguments], arguments},
      {[:directives], directives},
      {[:locations], locations}
    ])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.Document do
  def children(%@for{definitions: definitions}) do
    Wormwood.Traversal.maybe_compact_children([{[:definitions], definitions}])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.EnumTypeDefinition do
  def children(%@for{directives: directives, values: values}) do
    Wormwood.Traversal.maybe_compact_children([{[:directives], directives}, {[:values], values}])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.EnumValueDefinition do
  def children(%@for{value: value, directives: directives}) do
    Wormwood.Traversal.maybe_compact_children([{[:value], value}, {[:directives], directives}])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.Field do
  def children(%@for{arguments: arguments, directives: directives, selection_set: selection_set}) do
    Wormwood.Traversal.maybe_compact_children([
      {[:arguments], arguments},
      {[:directives], directives},
      {[:selection_set], selection_set}
    ])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.FieldDefinition do
  def children(%@for{arguments: arguments, type: type, directives: directives}) do
    Wormwood.Traversal.maybe_compact_children([{[:arguments], arguments}, {[:type], type}, {[:directives], directives}])
  end
end

defimpl Wormwood.Traversal.Node, for: [Wormwood.Language.Fragment, Wormwood.Language.InlineFragment] do
  def children(%@for{type_condition: type_condition, directives: directives, selection_set: selection_set}) do
    Wormwood.Traversal.maybe_compact_children([
      {[:type_condition], type_condition},
      {[:directives], directives},
      {[:selection_set], selection_set}
    ])
  end
end

defimpl Wormwood.Traversal.Node, for: [Wormwood.Language.FragmentSpread, Wormwood.Language.ScalarTypeDefinition] do
  def children(%@for{directives: directives}) do
    Wormwood.Traversal.maybe_compact_children([{[:directives], directives}])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.InputValueDefinition do
  def children(%@for{type: type, default_value: default_value, directives: directives}) do
    Wormwood.Traversal.maybe_compact_children([
      {[:type], type},
      {[:default_value], default_value},
      {[:directives], directives}
    ])
  end
end

defimpl Wormwood.Traversal.Node,
  for: [Wormwood.Language.InputObjectTypeDefinition, Wormwood.Language.InterfaceTypeDefinition, Wormwood.Language.SchemaDefinition] do
  def children(%@for{directives: directives, fields: fields}) do
    Wormwood.Traversal.maybe_compact_children([{[:directives], directives}, {[:fields], fields}])
  end
end

defimpl Wormwood.Traversal.Node, for: [Wormwood.Language.ListType, Wormwood.Language.NonNullType] do
  def children(%@for{type: type}) do
    Wormwood.Traversal.maybe_compact_children([{[:type], type}])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.ListValue do
  def children(%@for{values: values}) do
    Wormwood.Traversal.maybe_compact_children([{[:values], values}])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.ObjectTypeDefinition do
  def children(%@for{directives: directives, interfaces: interfaces, fields: fields}) do
    Wormwood.Traversal.maybe_compact_children([
      {[:directives], directives},
      {[:interfaces], interfaces},
      {[:fields], fields}
    ])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.ObjectValue do
  def children(%@for{fields: fields}) do
    Wormwood.Traversal.maybe_compact_children([{[:fields], fields}])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.OperationDefinition do
  def children(%@for{variable_definitions: variable_definitions, directives: directives, selection_set: selection_set}) do
    Wormwood.Traversal.maybe_compact_children([
      {[:variable_definitions], variable_definitions},
      {[:directives], directives},
      {[:selection_set], selection_set}
    ])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.SelectionSet do
  def children(%@for{selections: selections}) do
    Wormwood.Traversal.maybe_compact_children([{[:selections], selections}])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.TypeExtensionDefinition do
  def children(%@for{definition: definition}) do
    Wormwood.Traversal.maybe_compact_children([{[:definition], definition}])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.UnionTypeDefinition do
  def children(%@for{types: types, directives: directives}) do
    Wormwood.Traversal.maybe_compact_children([{[:types], types}, {[:directives], directives}])
  end
end

defimpl Wormwood.Traversal.Node, for: Wormwood.Language.VariableDefinition do
  def children(%@for{variable: variable, type: type, default_value: default_value}) do
    Wormwood.Traversal.maybe_compact_children([{[:variable], variable}, {[:type], type}, {[:default_value], default_value}])
  end
end
