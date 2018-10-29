defmodule Wormwood.Schema.JSON do
  def load!(%{"__schema" => schema}) do
    load_document(schema)
  end

  def load_default_value(json) do
    case json do
      nil ->
        nil

      _ when is_binary(json) ->
        value = OJSON.decode!(json)
        load_value(value)
    end
  end

  def load_value(value) do
    case value do
      _ when is_binary(value) ->
        %Wormwood.Language.StringValue{value: value}

      _ when is_boolean(value) ->
        %Wormwood.Language.BooleanValue{value: value}

      _ when is_float(value) ->
        %Wormwood.Language.FloatValue{value: value}

      _ when is_integer(value) ->
        %Wormwood.Language.IntValue{value: value}

      _ when is_list(value) ->
        load_list_value(value)

      _ when is_map(value) ->
        load_object_value(value)

      _ when is_nil(value) ->
        %Wormwood.Language.NullValue{}
    end
  end

  def load_list_value(value) do
    case value do
      _ when is_list(value) ->
        values = Enum.map(value, &load_value/1)
        %Wormwood.Language.ListValue{values: values}
    end
  end

  def load_object_value(value) do
    case value do
      _ when is_map(value) ->
        fields =
          Enum.map(value, fn {name, v} ->
            %Wormwood.Language.ObjectField{name: name, value: load_value(v)}
          end)

        %Wormwood.Language.ObjectValue{fields: fields}
    end
  end

  def load_directive_definition(json) do
    case json do
      %{"name" => name, "description" => description, "locations" => locations, "args" => args}
      when is_list(locations) and is_list(args) ->
        locations = Enum.map(locations, &load_directive_location/1)
        arguments = Enum.map(args, &load_input_value/1)

        %Wormwood.Language.DirectiveDefinition{
          description: description,
          name: name,
          arguments: arguments,
          directives: [],
          locations: locations
        }

      _ ->
        raise("type __Directive is invalid: #{inspect(json)}")
    end
  end

  def load_directive_location(json) do
    case json do
      _ when is_binary(json) and byte_size(json) > 0 ->
        json

      _ ->
        raise("enum __DirectiveLocation is invalid: #{inspect(json)}")
    end
  end

  def load_directive_deprecated(deprecated, reason) do
    if deprecated === true do
      directive_arguments =
        case reason do
          _ when is_binary(reason) and byte_size(reason) > 0 ->
            argument = %Wormwood.Language.Argument{
              name: "reason",
              value: %Wormwood.Language.StringValue{value: reason}
            }

            [argument]

          _ ->
            []
        end

      directive = %Wormwood.Language.Directive{name: "deprecated", arguments: directive_arguments}
      [directive]
    else
      []
    end
  end

  def load_document(json) do
    case json do
      %{"types" => types, "directives" => directives} when is_list(types) and is_list(directives) ->
        schema_definition = load_schema_definition(json)
        directives = Enum.map(directives, &load_directive_definition/1)
        types = Enum.map(types, &load_type/1)

        %Wormwood.Language.Document{
          definitions: [
            schema_definition
            | directives ++ types
          ]
        }
    end
  end

  def load_enum_value_definition(json) do
    case json do
      %{"name" => name, "description" => description, "deprecationReason" => reason, "isDeprecated" => deprecated} ->
        directives = load_directive_deprecated(deprecated, reason)
        %Wormwood.Language.EnumValueDefinition{value: name, description: description, directives: directives}
    end
  end

  def load_field_definition(json) do
    case json do
      %{
        "name" => name,
        "description" => description,
        "deprecationReason" => reason,
        "isDeprecated" => deprecated,
        "type" => type,
        "args" => args
      }
      when is_list(args) ->
        directives = load_directive_deprecated(deprecated, reason)
        arguments = Enum.map(args, &load_input_value/1)
        type = load_type_ref(type)

        %Wormwood.Language.FieldDefinition{
          name: name,
          description: description,
          arguments: arguments,
          directives: directives,
          type: type
        }
    end
  end

  def load_input_value(json) do
    case json do
      %{"name" => name, "description" => description, "type" => type, "defaultValue" => default_value} when is_binary(name) ->
        type = load_type_ref(type)
        default_value = load_default_value(default_value)

        %Wormwood.Language.InputValueDefinition{
          description: description,
          name: name,
          type: type,
          directives: [],
          default_value: default_value
        }

      _ ->
        raise("type __InputValue is invalid: #{inspect(json)}")
    end
  end

  def load_named_type(json) do
    case json do
      nil ->
        nil

      %{"name" => name} when is_binary(name) and byte_size(name) > 0 ->
        %Wormwood.Language.NamedType{name: name}
    end
  end

  def load_schema_definition(json) do
    case json do
      %{"queryType" => query_type, "mutationType" => mutation_type, "subscriptionType" => subscription_type} ->
        query_type = load_named_type(query_type)
        mutation_type = load_named_type(mutation_type)
        subscription_type = load_named_type(subscription_type)

        fields =
          for {name, named_type = %Wormwood.Language.NamedType{}} <- [
                mutation: mutation_type,
                query: query_type,
                subscription: subscription_type
              ],
              into: [] do
            %Wormwood.Language.FieldDefinition{
              arguments: [],
              description: nil,
              directives: [],
              name: to_string(name),
              type: named_type
            }
          end

        %Wormwood.Language.SchemaDefinition{directives: [], fields: fields}
    end
  end

  def load_type(json) do
    case json do
      %{"kind" => "ENUM", "name" => name, "description" => description, "enumValues" => values} when is_list(values) ->
        values = Enum.map(values, &load_enum_value_definition/1)
        %Wormwood.Language.EnumTypeDefinition{name: name, description: description, values: values}

      %{"kind" => "INPUT_OBJECT", "name" => name, "description" => description, "inputFields" => input_fields}
      when is_list(input_fields) ->
        input_fields = Enum.map(input_fields, &load_input_value/1)
        %Wormwood.Language.InputObjectTypeDefinition{name: name, description: description, fields: input_fields}

      %{"kind" => "INTERFACE", "name" => name, "description" => description, "fields" => fields, "possibleTypes" => possible_types}
      when is_list(fields) and is_list(possible_types) ->
        fields = Enum.map(fields, &load_field_definition/1)
        # NOTE: We currently don't have a place to put these :-(
        _possible_types = Enum.map(possible_types, &load_named_type/1)
        %Wormwood.Language.InterfaceTypeDefinition{name: name, description: description, fields: fields}

      %{"kind" => "OBJECT", "name" => name, "description" => description, "fields" => fields, "interfaces" => interfaces}
      when is_list(fields) and is_list(interfaces) ->
        fields = Enum.map(fields, &load_field_definition/1)
        interfaces = Enum.map(interfaces, &load_named_type/1)
        %Wormwood.Language.ObjectTypeDefinition{name: name, description: description, interfaces: interfaces, fields: fields}

      %{"kind" => "SCALAR", "name" => name, "description" => description} ->
        %Wormwood.Language.ScalarTypeDefinition{name: name, description: description}

      %{"kind" => "UNION", "name" => name, "description" => description, "possibleTypes" => possible_types} ->
        possible_types = Enum.map(possible_types, &load_named_type/1)
        %Wormwood.Language.UnionTypeDefinition{name: name, description: description, types: possible_types}
    end
  end

  @doc false
  def load_type_ref(json) do
    case json do
      %{"kind" => kind, "name" => name, "ofType" => nil}
      when kind in ["ENUM", "INPUT_OBJECT", "INTERFACE", "OBJECT", "SCALAR", "UNION"] ->
        %Wormwood.Language.NamedType{name: name}

      %{"kind" => "LIST", "name" => _, "ofType" => of_type} when not is_nil(of_type) ->
        type = load_type_ref(of_type)
        %Wormwood.Language.ListType{type: type}

      %{"kind" => "NON_NULL", "name" => _, "ofType" => of_type} when not is_nil(of_type) ->
        type = load_type_ref(of_type)
        %Wormwood.Language.NonNullType{type: type}
    end
  end
end
