defmodule Wormwood.Language do
  @moduledoc false

  @type t() ::
          Wormwood.Language.Argument.t()
          | Wormwood.Language.BooleanValue.t()
          | Wormwood.Language.Directive.t()
          | Wormwood.Language.Document.t()
          | Wormwood.Language.EnumTypeDefinition.t()
          | Wormwood.Language.EnumValue.t()
          | Wormwood.Language.Field.t()
          | Wormwood.Language.FieldDefinition.t()
          | Wormwood.Language.FloatValue.t()
          | Wormwood.Language.Fragment.t()
          | Wormwood.Language.FragmentSpread.t()
          | Wormwood.Language.InlineFragment.t()
          | Wormwood.Language.InputObjectTypeDefinition.t()
          | Wormwood.Language.InputValueDefinition.t()
          | Wormwood.Language.IntValue.t()
          | Wormwood.Language.InterfaceTypeDefinition.t()
          | Wormwood.Language.ListType.t()
          | Wormwood.Language.ListValue.t()
          | Wormwood.Language.NamedType.t()
          | Wormwood.Language.NonNullType.t()
          | Wormwood.Language.ObjectField.t()
          | Wormwood.Language.ObjectTypeDefinition.t()
          | Wormwood.Language.ObjectValue.t()
          | Wormwood.Language.OperationDefinition.t()
          | Wormwood.Language.ScalarTypeDefinition.t()
          | Wormwood.Language.SelectionSet.t()
          | Wormwood.Language.Source.t()
          | Wormwood.Language.StringValue.t()
          | Wormwood.Language.TypeExtensionDefinition.t()
          | Wormwood.Language.UnionTypeDefinition.t()
          | Wormwood.Language.Variable.t()
          | Wormwood.Language.VariableDefinition.t()

  # Value nodes
  @type value_t() ::
          Wormwood.Language.Variable.t()
          | Wormwood.Language.IntValue.t()
          | Wormwood.Language.FloatValue.t()
          | Wormwood.Language.StringValue.t()
          | Wormwood.Language.BooleanValue.t()
          | Wormwood.Language.EnumValue.t()
          | Wormwood.Language.ListValue.t()
          | Wormwood.Language.ObjectValue.t()

  # Type reference nodes
  @type type_reference_t() :: Wormwood.Language.NamedType.t() | Wormwood.Language.ListType.t() | Wormwood.Language.NonNullType.t()

  # Type definition nodes
  @type type_definition_t() ::
          Wormwood.Language.ObjectTypeDefinition.t()
          | Wormwood.Language.InterfaceTypeDefinition.t()
          | Wormwood.Language.UnionTypeDefinition.t()
          | Wormwood.Language.ScalarTypeDefinition.t()
          | Wormwood.Language.EnumTypeDefinition.t()
          | Wormwood.Language.InputObjectTypeDefinition.t()
          | Wormwood.Language.TypeExtensionDefinition.t()

  @type loc_t() :: %{file: String.t(), line: pos_integer(), column: pos_integer()}

  @type input_t() ::
          Wormwood.Language.BooleanValue.t()
          | Wormwood.Language.EnumValue.t()
          | Wormwood.Language.FloatValue.t()
          | Wormwood.Language.IntValue.t()
          | Wormwood.Language.ListValue.t()
          | Wormwood.Language.ObjectValue.t()
          | Wormwood.Language.StringValue.t()
          | Wormwood.Language.Variable.t()

  def subject(type = %{__struct__: _}) do
    case type do
      %Wormwood.Language.DirectiveDefinition{} -> "directive"
      %Wormwood.Language.EnumTypeDefinition{} -> "enum"
      %Wormwood.Language.Fragment{} -> "fragment"
      %Wormwood.Language.InputObjectTypeDefinition{} -> "input"
      %Wormwood.Language.InterfaceTypeDefinition{} -> "interface"
      %Wormwood.Language.ObjectTypeDefinition{} -> "type"
      %Wormwood.Language.OperationDefinition{operation: operation} when not is_nil(operation) -> to_string(operation)
      %Wormwood.Language.ScalarTypeDefinition{} -> "scalar"
      %Wormwood.Language.SchemaDefinition{} -> "schema"
      %Wormwood.Language.UnionTypeDefinition{} -> "union"
    end
  end
end
