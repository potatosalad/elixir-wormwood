defmodule Wormwood.Traversal.Stack do
  @type node_path() :: [term()]
  @type t() :: %__MODULE__{path: node_path()}
  defstruct parent: nil, path: [:root], root: nil, siblings: []

  def delete!(stack = %__MODULE__{}) do
    {_, new_stack} = get_and_update!(stack, fn _ -> :pop end)
    new_stack
  end

  def delete!(stack = %__MODULE__{}, path) when is_list(path) do
    {_, new_stack} = get_and_update!(stack, fn _ -> :pop end)
    new_stack
  end

  def fetch(stack = %__MODULE__{}) do
    path = __MODULE__.path(stack)
    fetch(stack, path)
  end

  def fetch(stack = %__MODULE__{}, path) when is_list(path) do
    do_fetch(path, stack)
  end

  def get_and_update!(stack = %__MODULE__{}, fun) when is_function(fun, 1) do
    path = __MODULE__.path(stack)
    get_and_update!(stack, path, fun)
  end

  def get_and_update!(stack = %__MODULE__{}, path, fun) when is_list(path) and is_function(fun, 1) do
    do_get_and_update!(path, stack, fun)
  end

  def path(%__MODULE__{path: path}) do
    flatten_path(path, [])
  end

  def update!(stack = %__MODULE__{}, node) do
    {_, new_stack} = get_and_update!(stack, &{&1, node})
    new_stack
  end

  def update!(stack = %__MODULE__{}, path, node) when is_list(path) do
    {_, new_stack} = get_and_update!(stack, path, &{&1, node})
    new_stack
  end

  @doc false
  defp do_get_and_update!([key | path], map, fun) when is_map(map) do
    Map.get_and_update!(map, key, &do_get_and_update!(path, &1, fun))
  end

  defp do_get_and_update!([index | path], list, fun) when is_integer(index) and index >= 0 and is_list(list) do
    if length(list) >= index + 1 do
      do_get_and_update_list!(list, index, [], &do_get_and_update!(path, &1, fun))
    else
      :lists.nth(index + 1, list)
    end
  end

  defp do_get_and_update!([], current, fun) do
    fun.(current)
  end

  @doc false
  defp do_get_and_update_list!([current | tail], 0, heads, fun) do
    case fun.(current) do
      {get, update} ->
        {get, :lists.reverse([update | heads], tail)}

      :pop ->
        {current, :lists.reverse(heads, tail)}

      other ->
        raise("the given function must return a two-element tuple or :pop, got: #{inspect(other)}")
    end
  end

  defp do_get_and_update_list!([head | tail], index, heads, fun) when is_integer(index) and index > 0 do
    do_get_and_update_list!(tail, index - 1, [head | heads], fun)
  end

  @doc false
  defp do_fetch([key | path], map) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        do_fetch(path, value)

      :error ->
        :error
    end
  end

  defp do_fetch([index | path], list) when is_integer(index) and index >= 0 and is_list(list) do
    if length(list) >= index + 1 do
      element = :lists.nth(index + 1, list)
      do_fetch(path, element)
    else
      :error
    end
  end

  defp do_fetch([], value) do
    {:ok, value}
  end

  defp do_fetch(_path, _value) do
    :error
  end

  @doc false
  defp flatten_path([], acc) do
    acc
  end

  defp flatten_path([[part] | rest], acc) do
    flatten_path(rest, [part | acc])
  end

  defp flatten_path([[part | tail] | rest], acc) do
    flatten_path([tail | rest], [part | acc])
  end

  defp flatten_path([part | rest], acc) do
    flatten_path(rest, [part | acc])
  end
end
