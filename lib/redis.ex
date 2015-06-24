defmodule Redis do
  def start do
    start_link("127.0.0.1", 6379, 1, "", :no_reconnect)
    |> elem 1
  end

  def start_link(host \\ "127.0.0.1", port \\ 6379, database \\ 0,
                 password \\ "", reconnect_sleep \\ :no_reconnect) when is_binary(host) do
    :eredis.start_link(String.to_char_list(host), port, database, String.to_char_list(password), reconnect_sleep)
  end

  def execute(pid, [h|_] = commands) when is_binary(h) do
    query(pid, commands)
  end
  def execute(pid, commands) do
    query_pipeline(pid, commands)
  end


  ### KEY OPERATIONS


  @doc ~S"""
  Removes the specified keys.

  ## Examples

      iex> execute(pid, set("key1", "Hello"))
      "OK"
      iex> execute(pid, set("key2", "World"))
      "OK"
      iex> execute(pid, set("key3", "Delete me!"))
      "OK"
      iex> execute(pid, del("key3"))
      "1"
      iex> execute(pid, del(["key1", "key2", "key3"]))
      "2"
  """
  def del(keys) when is_list(keys) do
    ["DEL"] ++ keys
  end
  def del(key), do: del([key])

  @doc ~S"""
  Serialize the value stored at key in a Redis-specific format.

  ## Examples

      iex> execute(pid, set("mykey", 10))
      "OK"
      iex> execute(pid, dump("mykey"))
      <<0, 192, 10, 6, 0, 248, 114, 63, 197, 251, 251, 95, 40>>
  """
  def dump(key) do
    ["DUMP", key]
  end

  @doc ~S"""
  Returns if key exists.

  ## Examples

      iex> execute(pid, set("key1", "Hello"))
      "OK"
      iex> execute(pid, exists("key1"))
      "1"
      iex> execute(pid, exists("key2"))
      "0"
  """
  def exists(key) do
    ["EXISTS", key]
  end


  ### STRING OPERATIONS


  @doc ~S"""
  Appends the value at the end of the string.

  ## Examples

      iex> execute(pid, exists("mykey"))
      "0"
      iex> execute(pid, append("mykey", "Hello"))
      "5"
      iex> execute(pid, append("mykey", " World"))
      "11"
      iex> execute(pid, get("mykey"))
      "Hello World"
  """
  def append(key, value) do
    ["APPEND", key, value]
  end

  @doc ~S"""
  Count the number of set bits (population counting) in a string.

  ## Examples

      iex> execute(pid, set("mykey", "foobar"))
      "OK"
      iex> execute(pid, bitcount("mykey"))
      "26"
      iex> execute(pid, bitcount("mykey", "0", "0"))
      "4"
      iex> execute(pid, bitcount("mykey", "1", "1"))
      "6"
  """
  def bitcount(key, from \\ "0", to \\ "-1") do
    ["BITCOUNT", key, from, to]
  end

  @doc ~S"""
  Perform a bitwise operation between multiple keys (containing string values)
  and store the result in the destination key.

  ## Examples

      iex> execute(pid, set("key1", "foobar"))
      "OK"
      iex> execute(pid, bitop("NOT", "dest", "key1"))
      "6"
      iex> execute(pid, get("dest"))
      << 153, 144, 144, 157, 158, 141 >>
      iex> execute(pid, set("key2", "abcdef"))
      "OK"
      iex> execute(pid, bitop("AND", "dest", ["key1", "key2"]))
      "6"
      iex> execute(pid, get("dest"))
      "`bc`ab"
  """
  def bitop(operation, destkey, keys) when is_list(keys) do
    ["BITOP", operation, destkey] ++ keys
  end
  def bitop(operation, destkey, key), do: bitop(operation, destkey, [key])

  @doc ~S"""
  Return the position of the first bit set to 1 or 0 in a string.

  ## Examples

      iex> execute(pid, set("mykey", <<255, 240, 0>>))
      "OK"
      iex> execute(pid, bitpos("mykey", 0))
      "12"
      iex> execute(pid, set("mykey", <<0, 255, 240>>))
      "OK"
      iex> execute(pid, bitpos("mykey", 1, 0))
      "8"
      iex> execute(pid, bitpos("mykey", "1", "2"))
      "16"
      iex> execute(pid, set("mykey", <<0, 0, 0>>))
      "OK"
      iex> execute(pid, bitpos("mykey", 1))
      "-1"
  """
  def bitpos(key, bit, from \\ "0", to \\ "-1") do
    ["BITPOS", key, bit, from, to]
  end

  @doc ~S"""
  Decrement the integer value of a key by one.

  ## Examples

      iex> execute(pid, set("mykey", 10))
      "OK"
      iex> execute(pid, decr("mykey"))
      "9"
      iex> execute(pid, set("mykey", "234293482390480948029348230948"))
      "OK"
      iex> execute(pid, decr("mykey"))
      "ERR value is not an integer or out of range"
  """
  def decr(key) do
    ["DECR", key]
  end

  @doc ~S"""
  Decrement the integer value of a key by the given number.

  Examples

      iex> execute(pid, set("key", 10))
      "OK"
      iex> execute(pid, decrby("key", 3))
      "7"
  """
  def decrby(key, decrement) do
    ["DECRBY", key, decrement]
  end

  @doc ~S"""
  Get the value of a key.

  ## Examples

      iex> execute(pid, get("nonexisting"))
      :undefined
      iex> execute(pid, set("mykey", "Hello"))
      "OK"
      iex> execute(pid, get("mykey"))
      "Hello"
  """
  def get(key) do
    ["GET", key]
  end

  @doc ~S"""
  Returns the bit value at offset in the string value stored at key.

  ## Examples

      iex> execute(pid, setbit("mykey", 7, 1))
      "0"
      iex> execute(pid, getbit("mykey", 0))
      "0"
      iex> execute(pid, getbit("mykey", 7))
      "1"
      iex> execute(pid, getbit("mykey", 100))
      "0"
  """
  def getbit(key, offset) do
    ["GETBIT", key, offset]
  end

  @doc ~S"""
  Returns the substring of the string value stored at key, determined by the offsets.

  ## Examples

      iex> execute(pid, set("mykey", "This is a string"))
      "OK"
      iex> execute(pid, getrange("mykey", 0, 3))
      "This"
      iex> execute(pid, getrange("mykey", -3, -1))
      "ing"
      iex> execute(pid, getrange("mykey", 0, -1))
      "This is a string"
      iex> execute(pid, getrange("mykey", 10, 100))
      "string"
  """
  def getrange(key, from, to) do
    ["GETRANGE", key, from, to]
  end

  @doc ~S"""
  Atomically sets key to value and returns the old value stored at key.

  ## Examples

      iex> execute(pid, incr("mycounter"))
      "1"
      iex> execute(pid, getset("mycounter", "0"))
      "1"
      iex> execute(pid, get("mycounter"))
      "0"
  """
  def getset(key, value) do
    ["GETSET", key, value]
  end

  @doc ~S"""
  Increments the number stored at key by one.

  ## Examples

      iex> execute(pid, set("mykey", "10"))
      "OK"
      iex> execute(pid, incr("mykey"))
      "11"
      iex> execute(pid, get("mykey"))
      "11"
  """
  def incr(key) do
    ["INCR", key]
  end

  @doc ~S"""
  Increments the number stored at key by `increment`.

  ## Examples

      iex> execute(pid, set("mykey", "10"))
      "OK"
      iex> execute(pid, incrby("mykey", 5))
      "15"
      iex> execute(pid, get("mykey"))
      "15"
  """
  def incrby(key, increment) do
    ["INCRBY", key, increment]
  end

  @doc ~S"""
  Increment the string representing a floating point number stored at key by the specified `increment`.

  ## Examples

      iex> execute(pid, set("mykey", 10.50))
      "OK"
      iex> execute(pid, incrbyfloat("mykey", 0.1))
      "10.6"
      iex> execute(pid, set("mykey", 5.0e3))
      "OK"
      iex> execute(pid, incrbyfloat("mykey", 2.0e2))
      "5200"
  """
  def incrbyfloat(key, increment) do
    ["INCRBYFLOAT", key, to_string(increment)]
  end

  @doc ~S"""
  Returns the values of all specified keys.

  ## Examples

      iex> execute(pid, set("key1", "Hello"))
      "OK"
      iex> execute(pid, set("key2", "World"))
      "OK"
      iex> execute(pid, mget("key1"))
      ["Hello"]
      iex> execute(pid, mget(["key1", "key2", "nonexisting"]))
      ["Hello", "World", :undefined]
  """
  def mget(keys) when is_list(keys) do
    ["MGET"] ++ keys
  end
  def mget(key) do
    mget([key])
  end

  @doc ~S"""
  Returns the values of all specified keys.

  ## Examples

      iex> execute(pid, mset("key1", "Yo"))
      "OK"
      iex> execute(pid, get("key1"))
      "Yo"
      iex> execute(pid, mset(["key1", "Hello", "key2", "World"]))
      "OK"
      iex> execute(pid, mget(["key1", "key2"]))
      ["Hello", "World"]
      iex> execute(pid, mset([{"key1", "Hello!"}, {"key2", "World!"}]))
      "OK"
      iex> execute(pid, mget(["key1", "key2"]))
      ["Hello!", "World!"]
  """
  def mset([h|_] = key_values) when is_list(key_values) and is_binary(h)  do
    ["MSET"] ++ key_values
  end
  def mset([h|_] = key_values) when is_list(key_values) and is_tuple(h) do
    key_values
    |> Enum.flat_map(&Tuple.to_list(&1))
    |> mset
  end
  def mset(key, value) do
    [key, value] |> mset
  end

  @doc ~S"""
  Sets the given keys to their respective values if they do not exist.

  ## Examples

      iex> execute(pid, msetnx(["key1", "Hello", "key2", "there"]))
      "1"
      iex> execute(pid, msetnx([{"key2", "there"}, {"key3", "world"}]))
      "0"
      iex> execute(pid, mget(["key1", "key2", "key3"]))
      ["Hello", "there", :undefined]
  """
  def msetnx([h|_] = key_values) when is_list(key_values) and is_binary(h)  do
    ["MSETNX"] ++ key_values
  end
  def msetnx([h|_] = key_values) when is_list(key_values) and is_tuple(h) do
    key_values
    |> Enum.flat_map(&Tuple.to_list(&1))
    |> msetnx
  end
  def msetnx(key, value) do
    [key, value] |> msetnx
  end

  @doc ~S"""
  Like `setex` but with expire time is milliseconds instead of seconds.

  ## Examples

      iex> execute(pid, psetex("mykey", 1000, "Hello"))
      "OK"
      iex> execute(pid, get("mykey"))
      "Hello"
  """
  def psetex(key, ms, value) do
    ["PSETEX", key, ms, value]
  end

  @doc ~S"""
  Set key to hold the string `value`.

  ## Examples

      iex> execute(pid, set("mykey", "Hello"))
      "OK"
      iex> execute(pid, get("mykey"))
      "Hello"
  """
  def set(key, value) do
    ["SET", key, to_string(value)]
  end

  @doc ~S"""
  Sets or clears the bit at offset in the string value stored at key.

  ## Examples

      iex> execute(pid, setbit("mykey", 7, 1))
      "0"
      iex> execute(pid, setbit("mykey", 7, 0))
      "1"
      iex> execute(pid, get("mykey"))
      << 0 >>
  """
  def setbit(key, offset, value) do
    ["SETBIT", key, offset, value]
  end

  @doc ~S"""
  Set `key` to hold the string `value` and set `key` to timeout after a given number of seconds.

  ## Examples

      iex> execute(pid, setex("mykey", 10, "Hello"))
      "OK"
      iex> execute(pid, get("mykey"))
      "Hello"
  """
  def setex(key, s, value) do
    ["SETEX", key, s, value]
  end

  @doc ~S"""
  Set `key` to hold string `value` if `key` does not exist.

  ## Examples

      iex> execute(pid, setnx("mykey", "Hello"))
      "1"
      iex> execute(pid, setnx("mykey", "World"))
      "0"
      iex> execute(pid, get("mykey"))
      "Hello"
  """
  def setnx(key, value) do
    ["SETNX", key, value]
  end

  @doc ~S"""
  Overwrites part of the string stored at key, starting at the specified offset, for the entire length of value.

  ## Examples

      iex> execute(pid, set("key1", "Hello World"))
      "OK"
      iex> execute(pid, setrange("key1", 6, "Redis"))
      "11"
      iex> execute(pid, get("key1"))
      "Hello Redis"
  """
  def setrange(key, offset, value) do
    ["SETRANGE", key, offset, value]
  end

  @doc ~S"""
  Returns the length of the string value stored at key.

  ## Examples

      iex> execute(pid, set("mykey", "Hello world"))
      "OK"
      iex> execute(pid, strlen("mykey"))
      "11"
      iex> execute(pid, strlen("nonexisting"))
      "0"
  """
  def strlen(key) do
    ["STRLEN", key]
  end










  defp query(pid, command) do
    pid
    |> :eredis.q(command)
    |> elem(1)
  end

  defp query_pipeline(pid, commands) do
    pid
    |> :eredis.qp(commands)
    |> Enum.map(&elem(&1, 1))
  end
end
