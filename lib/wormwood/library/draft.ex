defmodule Wormwood.Library.Draft do
  defstruct module: nil,
            schemas: [],
            directives: [],
            types: [],
            operations: [],
            fragments: []

  @doc false
  def build!(list) when is_list(list) do
    draft = %{types: old_types} = merge!(list)

    new_types =
      Enum.reject(old_types, fn
        %{name: "__" <> _} -> true
        _ -> false
      end)

    draft = %{draft | types: new_types}
    :ok = Wormwood.Library.Validation.Schema.validate!(draft)

    Wormwood.Library.from_draft!(draft)
  end

  @doc false
  def merge!(list = [head | tail]) do
    :ok = Wormwood.Library.Validation.Uniqueness.validate!(list)
    Enum.reduce(tail, head, &merge!/2)
  end

  @doc false
  def merge!(
        %__MODULE__{module: module, schemas: s1, directives: d1, types: t1, operations: o1, fragments: f1},
        %__MODULE__{module: module, schemas: s2, directives: d2, types: t2, operations: o2, fragments: f2}
      ) do
    schemas = s1 ++ s2
    directives = d1 ++ d2
    types = t1 ++ t2
    operations = o1 ++ o2
    fragments = f1 ++ f2

    %__MODULE__{
      module: module,
      schemas: schemas,
      directives: directives,
      types: types,
      operations: operations,
      fragments: fragments
    }
  end

  @doc false
  def import_document!(draft = %__MODULE__{}, document = %Wormwood.Language.Document{}) do
    %Wormwood.Language.Document{definitions: definitions} = annotate_document_location!(document)
    do_import_document(definitions, draft)
  end

  @doc false
  def annotate_document_location!(document = %Wormwood.Language.Document{source: source}) do
    file =
      case source do
        %Wormwood.Language.Source{name: name} when is_binary(name) ->
          name

        _ ->
          "(nofile)"
      end

    line_increment =
      case source do
        %Wormwood.Language.Source{line: line} when is_integer(line) and line >= 0 ->
          line

        _ ->
          0
      end

    {document = %Wormwood.Language.Document{}, nil} =
      Wormwood.Traversal.reduce(document, nil, fn
        node = %{loc: %{line: line, column: column}}, _parent, _path, nil ->
          loc = %{file: file, line: line + line_increment, column: column}
          node = %{node | loc: loc}
          {:cont, nil, {:update, node}}

        node = %{loc: nil}, _parent, _path, nil ->
          loc = %{file: file, line: line_increment, column: 0}
          node = %{node | loc: loc}
          {:cont, nil, {:update, node}}

        _node, _parent, _path, nil ->
          :skip
      end)

    document
  end

  @doc false
  defp do_import_document([definition = %{__struct__: module} | rest], draft = %{schemas: schemas})
       when module in [
              Wormwood.Language.SchemaDefinition
            ] do
    schemas = [definition | schemas]
    draft = %{draft | schemas: schemas}
    do_import_document(rest, draft)
  end

  defp do_import_document([definition = %{__struct__: module} | rest], draft = %{types: types})
       when module in [
              Wormwood.Language.EnumTypeDefinition,
              Wormwood.Language.InputObjectTypeDefinition,
              Wormwood.Language.InterfaceTypeDefinition,
              Wormwood.Language.ObjectTypeDefinition,
              Wormwood.Language.ScalarTypeDefinition,
              Wormwood.Language.UnionTypeDefinition
            ] do
    types = [definition | types]
    draft = %{draft | types: types}
    do_import_document(rest, draft)
  end

  defp do_import_document([definition = %{__struct__: module} | rest], draft = %{directives: directives})
       when module in [
              Wormwood.Language.DirectiveDefinition
            ] do
    directives = [definition | directives]
    draft = %{draft | directives: directives}
    do_import_document(rest, draft)
  end

  defp do_import_document([definition = %{__struct__: module} | rest], draft = %{operations: operations})
       when module in [
              Wormwood.Language.OperationDefinition
            ] do
    operations = [definition | operations]
    draft = %{draft | operations: operations}
    do_import_document(rest, draft)
  end

  defp do_import_document([definition = %{__struct__: module} | rest], draft = %{fragments: fragments})
       when module in [
              Wormwood.Language.Fragment
            ] do
    fragments = [definition | fragments]
    draft = %{draft | fragments: fragments}
    do_import_document(rest, draft)
  end

  defp do_import_document([], draft) do
    draft
  end
end
