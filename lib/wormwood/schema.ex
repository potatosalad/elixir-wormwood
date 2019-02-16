defmodule Wormwood.Schema do
  def normalize!(document = %Wormwood.Language.Document{definitions: [_ | _]}) do
    folder = fn node, _parent, _path, :ok ->
      case cleanup(node) do
        :cont ->
          :cont

        :skip ->
          :skip

        {:cont, node} ->
          {:cont, :ok, {:update, node}}

        {:skip, node} ->
          {:skip, :ok, {:update, node}}
      end
    end

    {document, :ok} = Wormwood.Traversal.reduce(document, :ok, folder)

    document
  end

  @doc false
  defp cleanup(node) do
    case node do
      %Wormwood.Language.Directive{arguments: arguments} ->
        arguments = sort_by_name(arguments)
        node = %{node | arguments: arguments}
        {:skip, node}

      %Wormwood.Language.DirectiveDefinition{directives: directives, arguments: arguments} ->
        directives = sort_by_name(directives)
        arguments = sort_by_name(arguments)
        node = %{node | directives: directives, arguments: arguments}
        {:cont, node}

      %Wormwood.Language.Document{definitions: definitions} ->
        definitions =
          Enum.reject(definitions, fn
            %{name: "__" <> _} -> true
            _ -> false
          end)

        definitions =
          Enum.sort_by(definitions, fn
            %Wormwood.Language.SchemaDefinition{} -> {0, :schema}
            %Wormwood.Language.DirectiveDefinition{name: name} -> {1, name}
            %{__struct__: _module, name: name} -> {2, name}
            %{__struct__: module} -> {3, module}
          end)

        node = %{node | definitions: definitions}
        {:cont, node}

      %Wormwood.Language.EnumTypeDefinition{directives: directives, values: values} ->
        directives = sort_by_name(directives)
        values = Enum.sort_by(values, fn %{__struct__: _, value: value} -> value end)
        node = %{node | directives: directives, values: values}
        {:cont, node}

      %Wormwood.Language.EnumValueDefinition{directives: directives} ->
        directives = sort_by_name(directives)
        node = %{node | directives: directives}
        {:skip, node}

      %Wormwood.Language.Field{directives: directives, arguments: arguments} ->
        directives = sort_by_name(directives)
        arguments = sort_by_name(arguments)
        node = %{node | directives: directives, arguments: arguments}
        {:cont, node}

      %Wormwood.Language.FieldDefinition{directives: directives, arguments: arguments} ->
        directives = sort_by_name(directives)
        arguments = sort_by_name(arguments)
        node = %{node | directives: directives, arguments: arguments}
        {:cont, node}

      %Wormwood.Language.Fragment{directives: directives} ->
        directives = sort_by_name(directives)
        node = %{node | directives: directives}
        {:cont, node}

      %Wormwood.Language.FragmentSpread{directives: directives} ->
        directives = sort_by_name(directives)
        node = %{node | directives: directives}
        {:cont, node}

      %Wormwood.Language.InlineFragment{directives: directives} ->
        directives = sort_by_name(directives)
        node = %{node | directives: directives}
        {:cont, node}

      %Wormwood.Language.InputObjectTypeDefinition{directives: directives, fields: fields} ->
        directives = sort_by_name(directives)
        fields = sort_by_name(fields)
        node = %{node | directives: directives, fields: fields}
        {:cont, node}

      %Wormwood.Language.InterfaceTypeDefinition{directives: directives, fields: fields} ->
        directives = sort_by_name(directives)
        fields = sort_by_name(fields)
        node = %{node | directives: directives, fields: fields}
        {:cont, node}

      %Wormwood.Language.ObjectTypeDefinition{directives: directives, fields: fields} ->
        directives = sort_by_name(directives)
        fields = sort_by_name(fields)
        node = %{node | directives: directives, fields: fields}
        {:cont, node}

      %Wormwood.Language.SchemaDefinition{directives: directives, fields: fields} ->
        directives = sort_by_name(directives)
        fields = sort_by_name(fields)
        node = %{node | directives: directives, fields: fields}
        {:cont, node}

      %Wormwood.Language.UnionTypeDefinition{directives: directives, types: types} ->
        directives = sort_by_name(directives)
        types = sort_by_name(types)
        node = %{node | directives: directives, types: types}
        {:cont, node}

      _ ->
        :cont
    end
  end

  @doc false
  defp sort_by_name(list) do
    Enum.sort_by(list, fn %{__struct__: _, name: name} -> name end)
  end
end
