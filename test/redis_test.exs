defmodule RedisTest do
  use ExUnit.Case
  import Redis
  doctest Redis

  setup do
    pid = start
    Process.put(:pid, pid)

    :eredis.q(pid, ["FLUSHDB"])

    :ok
  end

  def pid do
    Process.get(:pid)
  end

  test "simple api" do
    assert execute(pid, get("mykey")) == :undefined
    assert execute(pid, set("mykey", "hello world")) == "OK"
    assert execute(pid, get("mykey")) == "hello world"
  end

  test "pipelined api" do
    commands = [
      get("mykey"),
      set("mykey", "hello world"),
      get("mykey")
    ]

    result = execute(pid, commands)

    assert result == [:undefined, "OK", "hello world"]
  end
end
