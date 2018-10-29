defmodule Wormwood.Library.Notation.Error do
  @moduledoc """
  Exception raised when a library is invalid
  """
  defexception message: "Invalid library notation"

  def exception(message) do
    %__MODULE__{message: message}
  end
end
