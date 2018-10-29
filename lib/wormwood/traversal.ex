defmodule Wormwood.Traversal do
  alias __MODULE__.Node
  alias __MODULE__.Stack

  @type reduce_control() :: :cont | :halt | :skip
  @type reduce_action() :: :delete | {:update, Node.t()}
  @type reduce_function(acc_type) ::
          (node :: Node.t(), parent :: nil | Node.t(), path :: Stack.path(), acc :: acc_type ->
             reduce_control() | {reduce_control(), acc_type} | {reduce_control(), acc_type, reduce_action()})
  @type reduce_function() :: reduce_function(term())

  @spec reduce(Node.t(), acc, reduce_function(acc)) :: {Node.t(), acc} when acc: any()
  def reduce(node, acc, fun) when is_function(fun, 4) do
    stack = %Stack{root: node}

    case do_reduce(node, stack, acc, fun) do
      {control, %Stack{root: root}, new_acc} when control in [:halted, :jumped] ->
        {root, new_acc}
    end
  end

  @spec maybe_compact_children([{[term()], [term()]}]) :: [{[term()], [term()]}]
  def maybe_compact_children(list = [_ | _]) do
    list
    |> Enum.filter(fn
      {_path, []} -> false
      {_path, nil} -> false
      {_path, _} -> true
    end)
    |> Enum.flat_map(fn
      {base, children = [_ | _]} ->
        for {child, index} <- Enum.with_index(children), into: [] do
          {[index | base], child}
        end

      {base, child} ->
        [{base, child}]
    end)
  end

  @doc false
  defp do_reduce(node, stack, acc, fun) do
    case do_reduce_once(node, stack, acc, fun) do
      {:cont, new_node, new_stack, new_acc} ->
        do_reduce_children(new_node, new_stack, new_acc, fun)

      {:halt, _new_node, new_stack, new_acc} ->
        {:halted, new_stack, new_acc}

      {:skip, _new_node, new_stack, new_acc} ->
        do_reduce_siblings(new_stack, new_acc, fun)
    end
  end

  @doc false
  defp do_reduce_once(node, stack = %Stack{parent: parent}, acc, fun) do
    case fun.(node, parent, Stack.path(stack), acc) do
      control when control in [:cont, :halt, :skip] ->
        {control, node, stack, acc}

      {control, new_acc} when control in [:cont, :halt, :skip] ->
        {control, node, stack, new_acc}

      {control, new_acc, :delete} when control in [:cont, :halt, :skip] ->
        {control, nil, Stack.delete!(stack), new_acc}

      {control, new_acc, {:update, new_node}} when control in [:cont, :halt, :skip] ->
        {control, new_node, Stack.update!(stack, new_node), new_acc}
    end
  end

  @doc false
  defp do_reduce_children(node, stack = %Stack{path: path}, acc, fun) do
    case Node.children(node) do
      [] ->
        do_reduce_siblings(stack, acc, fun)

      children = [_ | _] ->
        child_path = [:child | path]
        child_stack = %Stack{stack | parent: node, path: child_path, siblings: children}

        case do_reduce_siblings(child_stack, acc, fun) do
          {:jumped, %Stack{root: root}, new_acc} ->
            do_reduce_siblings(%Stack{stack | root: root}, new_acc, fun)

          {:halted, new_stack = %Stack{}, new_acc} ->
            {:halted, new_stack, new_acc}
        end
    end
  end

  @doc false
  defp do_reduce_siblings(stack = %Stack{siblings: []}, acc, _fun) do
    {:jumped, stack, acc}
  end

  defp do_reduce_siblings(old_stack = %Stack{path: old_path, siblings: [{add_path, sibling} | siblings]}, acc, fun) do
    new_path = [add_path | tl(old_path)]
    new_stack = %Stack{old_stack | path: new_path, siblings: siblings}
    do_reduce(sibling, new_stack, acc, fun)
  end
end
