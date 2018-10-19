defmodule WormwoodTest do
  use ExUnit.Case
  doctest Wormwood

  test "greets the world" do
    assert Wormwood.hello() == :world
  end
end
