defmodule Wormwood.Library.CompilationError do
  defexception depth: 2, errors: [], reason: nil

  import Wormwood.Library.Errors, only: [format_indent!: 2]

  def message(%__MODULE__{depth: depth, errors: errors, reason: reason}) do
    details =
      errors
      |> Enum.map(&"- #{format_indent!(Exception.message(&1), depth)}")
      |> Enum.join("\n")

    message = "Compilation failed:\n" <> details

    if is_nil(reason) or reason === <<>> do
      message
    else
      message <> "\n" <> format_indent!("Reason:\n\n" <> reason, depth) <> "\n"
    end
  end
end
