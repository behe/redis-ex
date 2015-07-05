defmodule Redis do
  def start do
    start_link("127.0.0.1", 6379, 1, "", :no_reconnect)
    |> elem 1
  end

  def start_link(host \\ "127.0.0.1", port \\ 6379, database \\ 0,
                 password \\ "", reconnect_sleep \\ :no_reconnect) when is_binary(host) do
    :eredis.start_link(String.to_char_list(host), port, database, String.to_char_list(password), reconnect_sleep)
  end

  def execute(pid, [h|_] = commands) when is_binary(h), do: query(pid, commands)
  def execute(pid, commands), do: query_pipeline(pid, commands)


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
  def del(keys) when is_list(keys), do: ["DEL"] ++ keys
  def del(key), do: del([key])

  @doc ~S"""
  Serialize the value stored at key in a Redis-specific format.

  ## Examples

      iex> execute(pid, set("mykey", 10))
      "OK"
      iex> execute(pid, dump("mykey"))
      <<0, 192, 10, 6, 0, 248, 114, 63, 197, 251, 251, 95, 40>>
  """
  def dump(key), do: ["DUMP", key]

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
  def exists(key), do: ["EXISTS", key]

  @doc ~S"""
  Set a timeout on key. After the timeout has expired, the key will automatically be deleted.

  ## Examples

      iex> execute(pid, set("mykey", "Hello"))
      "OK"
      iex> execute(pid, expire("mykey", 10))
      "1"
      iex> execute(pid, ttl("mykey"))
      "10"
      iex> execute(pid, set("mykey", "Hello World"))
      "OK"
      iex> execute(pid, ttl("mykey"))
      "-1"
  """
  def expire(key, seconds), do: ["EXPIRE", key, seconds]

  @doc ~S"""
  Same as `expire`, but takes a Unix `timestamp` instead of seconds to live.

  ## Examples

      iex> execute(pid, set("mykey", "Hello"))
      "OK"
      iex> execute(pid, exists("mykey"))
      "1"
      iex> execute(pid, expireat("mykey", 1293840000))
      "1"
      iex> execute(pid, exists("mykey"))
      "0"
  """
  def expireat(key, timestamp), do: ["EXPIREAT", key, timestamp]

  @doc ~S"""
  Returns all keys matching `pattern`.

  ## Examples

      iex> execute(pid, mset([{"one", 1}, {"two", 2}, {"three", 3}, {"four", 4}]))
      iex> execute(pid, keys("*o*")) |> Enum.sort
      ["four", "one", "two"]
      iex> execute(pid, keys("t??"))
      ["two"]
      iex> execute(pid, keys("*")) |> Enum.sort
      ["four", "one", "three", "two"]
  """
  def keys(pattern), do: ["KEYS", pattern]

  # @doc ~S"""
  # Atomically transfer a key from a source Redis instance to a destination Redis instance.
  #
  # ## Examples
  #
  #     iex> execute(pid, set("mykey", "Hello"))
  #     "OK"
  #     iex> execute(pid, migrate("127.0.0.1", "6379", "mykey", "2", "0"))
  #     "OK"
  #     iex> execute(pid, get("mykey"))
  #     :undefined
  # """
  # def migrate(host, port, key, dbid, timeout) do
  #   ["MIGRATE", host, port, key, dbid, timeout]
  # end

  @doc ~S"""
  Move key from the currently selected database to the specified destination database.

  ## Examples

      iex> execute(pid, [["SELECT", "2"], ["DEL", "mykey"], ["SELECT", "1"]])
      iex> execute(pid, set("mykey", "Hello"))
      "OK"
      iex> execute(pid, move("mykey", 2))
      "1"
      iex> execute(pid, get("mykey"))
      :undefined
  """
  def move(key, dbid), do: ["MOVE", key, dbid]

  @doc ~S"""
  Move key from the currently selected database to the specified destination database.

  ## Examples

      iex> execute(pid, lpush("mylist", "Hello World"))
      "1"
      iex> execute(pid, object("refcount", "mylist"))
      "1"
      iex> execute(pid, object("encoding", "mylist"))
      "ziplist"
      iex> execute(pid, object("idletime", "mylist"))
      "0"
      iex> execute(pid, set("foo", 1000))
      "OK"
      iex> execute(pid, object("encoding", "foo"))
      "int"
      iex> execute(pid, append("foo", "bar"))
      "7"
      iex> execute(pid, object("encoding", "foo"))
      "raw"
  """
  def object(subcommand, key), do: ["OBJECT", subcommand, key]

  @doc ~S"""
  Remove the existing timeout on `key`.

  ## Examples

      iex> execute(pid, set("mykey", "Hello"))
      "OK"
      iex> execute(pid, expire("mykey", 10))
      "1"
      iex> execute(pid, ttl("mykey"))
      "10"
      iex> execute(pid, persist("mykey"))
      "1"
      iex> execute(pid, ttl("mykey"))
      "-1"
  """
  def persist(key), do: ["PERSIST", key]

  @doc ~S"""
  Remove `key` after `ms` timeout.

  ## Examples

      iex> execute(pid, set("mykey", "Hello"))
      "OK"
      iex> execute(pid, pexpire("mykey", 1900))
      "1"
      iex> execute(pid, ttl("mykey"))
      "2"
  """
  def pexpire(key, ms), do: ["PEXPIRE", key, ms]

  @doc ~S"""
  Remove `key` at ms timestamp.

  ## Examples

      iex> execute(pid, set("mykey", "Hello"))
      "OK"
      iex> execute(pid, pexpireat("mykey", 1293840000000))
      "1"
      iex> execute(pid, ttl("mykey"))
      "-2"
  """
  def pexpireat(key, ms_timestamp), do: ["PEXPIREAT", key, ms_timestamp]

  @doc ~S"""
  Returns the remaining time to live in ms.
  """
  def pttl(key), do: ["PTTL", key]

  @doc ~S"""
  Return a random key from the currently selected database.

  ## Examples

      iex> execute(pid, randomkey)
      :undefined
  """
  def randomkey, do: ["RANDOMKEY"]

  @doc ~S"""
  Renames `key` to `newkey`.

  ## Examples

      iex> execute(pid, set("mykey", "Hello"))
      "OK"
      iex> execute(pid, rename("mykey", "myotherkey"))
      "OK"
      iex> execute(pid, get("myotherkey"))
      "Hello"
  """
  def rename(key, newkey), do: ["RENAME", key, newkey]

  @doc ~S"""
  Renames `key` to `newkey` if `newkey` does not yet exist.

  ## Examples

      iex> execute(pid, set("mykey", "Hello"))
      "OK"
      iex> execute(pid, set("myotherkey", "World"))
      "OK"
      iex> execute(pid, renamenx("mykey", "myotherkey"))
      "0"
      iex> execute(pid, get("myotherkey"))
      "World"
  """
  def renamenx(key, newkey), do: ["RENAMENX", key, newkey]

  @doc ~S"""
  Deserialize the provided `serialized_value` into `key`.

  ## Examples

      iex> value = <<10, 17, 17, 0, 0, 0, 14, 0, 0, 0, 3, 0, 0, 242, 2, 243, 2,
      iex> 244, 255, 6, 0, 90, 49, 95, 28, 103, 4, 33, 24>>
      iex> execute(pid, restore("mykey", 0, value))
      "OK"
      iex> execute(pid, type("mykey"))
      "list"
      iex> execute(pid, lrange("mykey", 0, -1))
      ["1", "2", "3"]
  """
  def restore(key, ttl, serialized_value), do: ["RESTORE", key, ttl, serialized_value]

  @doc ~S"""
  Incrementally iterate over a collection of elements.

  ## Examples

      iex> execute(pid, set("mykey", "Hello"))
      iex> execute(pid, scan(0))
      ["0", ["mykey"]]
  """
  def scan(cursor, options \\ []), do: ["SCAN", cursor] ++ options

  @doc ~S"""
  Returns or stores the elements contained in the list, set or sorted set at `key`.

  ## Examples

      iex> execute(pid, rpush("mylist", ["2", "1", "3"]))
      iex> execute(pid, sort("mylist"))
      ["1", "2", "3"]
      iex> execute(pid, sort("mylist", ["DESC"]))
      ["3", "2", "1"]
      iex> execute(pid, sort("mylist", ["LIMIT", 0, 2]))
      ["1", "2"]
      iex> execute(pid, sort("mylist", ["LIMIT", 0, 2, "DESC"]))
      ["3", "2"]
      iex> execute(pid, sort("mylist", ["BY", "nosort"]))
      ["2", "1", "3"]
  """
  def sort(key, args) when is_list(args), do: ["SORT", key] ++ args
  def sort(key), do: sort(key, [])

  @doc ~S"""
  Returns the remaining time to live of a key that has a timeout.

  ## Examples

      iex> execute(pid, set("mykey", "Hello"))
      "OK"
      iex> execute(pid, expire("mykey", 10))
      "1"
      iex> execute(pid, ttl("mykey"))
      "10"
  """
  def ttl(key), do: ["TTL", key]

  @doc ~S"""
  Returns the string representation of the type of the value stored at `key`.

  ## Examples

      iex> execute(pid, set("key1", "value"))
      "OK"
      iex> execute(pid, lpush("key2", "value"))
      "1"
      iex> execute(pid, sadd("key3", "value"))
      "1"
      iex> execute(pid, type("key1"))
      "string"
      iex> execute(pid, type("key2"))
      "list"
      iex> execute(pid, type("key3"))
      "set"
  """
  def type(key), do: ["TYPE", key]


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
  Sets the given keys to their respective values.

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
  def msetnx([h|_] = key_values) when is_binary(h)  do
    ["MSETNX"] ++ key_values
  end
  def msetnx([h|_] = key_values) when is_tuple(h) do
    key_values
    |> Enum.flat_map(&Tuple.to_list(&1))
    |> msetnx
  end
  def msetnx(key, value), do: [key, value] |> msetnx

  @doc ~S"""
  Like `setex` but with expire time is milliseconds instead of seconds.

  ## Examples

      iex> execute(pid, psetex("mykey", 1000, "Hello"))
      "OK"
      iex> execute(pid, get("mykey"))
      "Hello"
  """
  def psetex(key, ms, value), do: ["PSETEX", key, ms, value]

  @doc ~S"""
  Set key to hold the string `value`.

  ## Examples

      iex> execute(pid, set("mykey", "Hello"))
      "OK"
      iex> execute(pid, get("mykey"))
      "Hello"
  """
  def set(key, value), do: ["SET", key, to_string(value)]

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
  def setbit(key, offset, value), do: ["SETBIT", key, offset, value]

  @doc ~S"""
  Set `key` to hold the string `value` and set `key` to timeout after a given number of seconds.

  ## Examples

      iex> execute(pid, setex("mykey", 10, "Hello"))
      "OK"
      iex> execute(pid, get("mykey"))
      "Hello"
  """
  def setex(key, s, value), do: ["SETEX", key, s, value]

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
  def setnx(key, value), do: ["SETNX", key, value]

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
  def setrange(key, offset, value), do: ["SETRANGE", key, offset, value]

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
  def strlen(key), do: ["STRLEN", key]


  ### LIST OPERATIONS


  @doc ~S"""
  Blocking list pop primitive.

  ## Examples

      iex> execute(pid, rpush("list1", ["a", "b", "c"]))
      "3"
      iex> execute(pid, blpop("list1", "0"))
      ["list1", "a"]
      iex> execute(pid, blpop(["list2", "list1"], "0"))
      ["list1", "b"]
  """
  def blpop(keys, timeout) when is_list(keys), do: ["BLPOP"] ++ keys ++ [timeout]
  def blpop(key, timeout), do: blpop([key], timeout)

  @doc ~S"""
  Blocking list pop primitive.

  ## Examples

      iex> execute(pid, rpush("list1", ["a", "b", "c"]))
      "3"
      iex> execute(pid, brpop("list1", "0"))
      ["list1", "c"]
      iex> execute(pid, brpop(["list2", "list1"], "0"))
      ["list1", "b"]
  """
  def brpop(keys, timeout) when is_list(keys), do: ["BRPOP"] ++ keys ++ [timeout]
  def brpop(key, timeout), do: brpop([key], timeout)

  @doc ~S"""
  Returns and removes the last element (tail) of the list stored at `source`,
  and pushes the element at the first element (head) of the list stored at
  `destination`. Will wait for `timeout` seconds for elements to be added to the
  `source` list if it is empty.

  ## Examples

      iex> execute(pid, rpush("mylist", ["one", "two", "three"]))
      "3"
      iex> execute(pid, brpoplpush("mylist", "myotherlist", 1))
      "three"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["one", "two"]
      iex> execute(pid, lrange("myotherlist", 0, -1))
      ["three"]
  """
  def brpoplpush(source, dest, timeout), do: ["BRPOPLPUSH", source, dest, timeout]

  @doc ~S"""
  Returns the element at index `index` in the list stored at `key`.

  ## Examples

      iex> execute(pid, rpush("mylist", ["Hello", "World"]))
      "2"
      iex> execute(pid, lindex("mylist", 0))
      "Hello"
      iex> execute(pid, lindex("mylist", -1))
      "World"
      iex> execute(pid, lindex("mylist", 3))
      :undefined
  """
  def lindex(key, index), do: ["LINDEX", key, index]

  @doc ~S"""
  Inserts `value` in the list stored at `key` either before or after the
  reference value `pivot`.

  ## Examples

      iex> execute(pid, rpush("mylist", ["Hello", "World"]))
      "2"
      iex> execute(pid, linsert("mylist", "BEFORE", "World", "There"))
      "3"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["Hello", "There", "World"]
  """
  def linsert(key, pos, pivot, value), do: ["LINSERT", key, pos, pivot, value]

  @doc ~S"""
  Returns the length of the list stored at `key`.

  ## Examples

      iex> execute(pid, rpush("mylist", ["Hello", "World"]))
      "2"
      iex> execute(pid, llen("mylist"))
      "2"
  """
  def llen(key), do: ["LLEN", key]

  @doc ~S"""
  Returns the length of the list stored at `key`.

  ## Examples

      iex> execute(pid, rpush("mylist", ["one", "two", "three"]))
      "3"
      iex> execute(pid, lpop("mylist"))
      "one"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["two", "three"]
  """
  def lpop(key), do: ["LPOP", key]

  @doc ~S"""
  Inserts all the specified `values` at the head of the list stored at `key`.
  Creates `key` if it does not already exist.

  ## Examples

      iex> execute(pid, lpush("mylist", "World"))
      "1"
      iex> execute(pid, lpush("mylist", "Hello"))
      "2"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["Hello", "World"]
  """
  def lpush(key, values) when is_list(values), do: ["LPUSH", key] ++ values
  def lpush(key, value), do: lpush(key, [value])

  @doc ~S"""
  Inserts `value` at the head of the list stored at `key`, only if `key` already
  exists and holds a list.

  ## Examples

      iex> execute(pid, lpush("mylist", "World"))
      "1"
      iex> execute(pid, lpushx("mylist", "Hello"))
      "2"
      iex> execute(pid, lpushx("myotherlist", "Hello"))
      "0"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["Hello", "World"]
      iex> execute(pid, lrange("myotherlist", 0, -1))
      []
  """
  def lpushx(key, value), do: ["LPUSHX", key, value]

  @doc ~S"""
  Returns the specified elements of the list stored at `key`.

  ## Examples

      iex> execute(pid, rpush("mylist", ["one", "two", "three"]))
      "3"
      iex> execute(pid, lrange("mylist", 0, 0))
      ["one"]
      iex> execute(pid, lrange("mylist", -3, 2))
      ["one", "two", "three"]
      iex> execute(pid, lrange("mylist", -100, 100))
      ["one", "two", "three"]
      iex> execute(pid, lrange("mylist", 5, 10))
      []
  """
  def lrange(key, from, to), do: ["LRANGE", key, from, to]

  @doc ~S"""
  Removes the first `count` occurrences of elements equal to `value` from the
  list stored at `key`.

  ## Examples

      iex> execute(pid, rpush("mylist", ["hello", "hello", "foo", "hello"]))
      "4"
      iex> execute(pid, lrem("mylist", -2, "hello"))
      "2"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["hello", "foo"]
  """
  def lrem(key, count, value), do: ["LREM", key, count, value]

  @doc ~S"""
  Sets the list element at `index` to `value`.

  ## Examples

      iex> execute(pid, rpush("mylist", ["one", "two", "three"]))
      "3"
      iex> execute(pid, lset("mylist", 0, "four"))
      "OK"
      iex> execute(pid, lset("mylist", -2, "five"))
      "OK"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["four", "five", "three"]
  """
  def lset(key, index, value), do: ["LSET", key, index, value]

  @doc ~S"""
  Trim an existing list so that it will only contain elements at the specified
  range.

  ## Examples

      iex> execute(pid, rpush("mylist", ["one", "two", "three"]))
      "3"
      iex> execute(pid, ltrim("mylist", 1, -1))
      "OK"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["two", "three"]
  """
  def ltrim(key, start, stop), do: ["LTRIM", key, start, stop]

  @doc ~S"""
  Removes and returns the last element of the list stored at `key`.

  ## Examples

      iex> execute(pid, rpush("mylist", ["one", "two", "three"]))
      "3"
      iex> execute(pid, rpop("mylist"))
      "three"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["one", "two"]
  """
  def rpop(key), do: ["RPOP", key]

  @doc ~S"""
  Atomically returns and removes the last element (tail) of the list stored at
  `source`, and pushes the element at the first element (head) of the list stored
  at `destination`.

  ## Examples

      iex> execute(pid, rpush("mylist", ["one", "two", "three"]))
      "3"
      iex> execute(pid, rpoplpush("mylist", "myotherlist"))
      "three"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["one", "two"]
      iex> execute(pid, lrange("myotherlist", 0, -1))
      ["three"]
  """
  def rpoplpush(source, dest), do: ["RPOPLPUSH", source, dest]

  @doc ~S"""
  Insert all the specified `values` at the tail of the list stored at `key`.

  ## Examples

      iex> execute(pid, rpush("mylist", "Hello"))
      "1"
      iex> execute(pid, rpush("mylist", "World"))
      "2"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["Hello", "World"]
      iex> execute(pid, rpush("mylist", ["Wide", "Web"]))
      "4"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["Hello", "World", "Wide", "Web"]
  """
  def rpush(key, values) when is_list(values), do: ["RPUSH", key] ++ values
  def rpush(key, value), do: rpush(key, [value])

  @doc ~S"""
  Insert all the specified `value` at the tail of the list stored at `key`, only
  if the `key` exists.

  ## Examples

      iex> execute(pid, rpush("mylist", "Hello"))
      "1"
      iex> execute(pid, rpushx("mylist", "World"))
      "2"
      iex> execute(pid, rpushx("myotherlist", "World"))
      "0"
      iex> execute(pid, lrange("mylist", 0, -1))
      ["Hello", "World"]
      iex> execute(pid, lrange("myotherlist", 0, -1))
      []
  """
  def rpushx(key, value), do: ["RPUSHX", key, value]


  ### SET OPERATIONS


  @doc ~S"""
  Add the specified `members` to the set stored at `key`.

  ## Examples

      iex> execute(pid, sadd("myset", "Hello"))
      "1"
      iex> execute(pid, sadd("myset", "World"))
      "1"
      iex> execute(pid, sadd("myset", ["Hello", "World"]))
      "0"
      iex> execute(pid, smembers("myset")) |> Enum.sort
      ["Hello", "World"]
  """
  def sadd(key, values) when is_list(values), do: ["SADD", key] ++ values
  def sadd(key, value), do: sadd(key, [value])

  @doc ~S"""
  Returns the number of elements of the set stored at `key`.

  ## Examples

      iex> execute(pid, sadd("myset", ["Hello", "World"]))
      "2"
      iex> execute(pid, scard("myset"))
      "2"
  """
  def scard(key), do: ["SCARD", key]

  @doc ~S"""
  Returns the members of the set resulting from the difference between the first
  set and all the successive sets.

  ## Examples

      iex> execute(pid, sadd("key1", ["a", "b", "c"]))
      "3"
      iex> execute(pid, sadd("key2", ["c", "d", "e"]))
      "3"
      iex> execute(pid, sdiff("key1")) |> Enum.sort
      ["a", "b", "c"]
      iex> execute(pid, sdiff("key1", ["key2"])) |> Enum.sort
      ["a", "b"]
  """
  def sdiff(key, keys \\ []), do: ["SDIFF", key] ++ keys

  @doc ~S"""
  Writes the members of the set resulting from the difference between the first
  set and all the successive sets to `dest`.

  ## Examples

      iex> execute(pid, sadd("key1", ["a", "b", "c"]))
      "3"
      iex> execute(pid, sadd("key2", ["c", "d", "e"]))
      "3"
      iex> execute(pid, sdiffstore("key", "key1"))
      "3"
      iex> execute(pid, smembers("key")) |> Enum.sort
      ["a", "b", "c"]
      iex> execute(pid, sdiffstore("key", "key1", ["key2"]))
      "2"
      iex> execute(pid, smembers("key")) |> Enum.sort
      ["a", "b"]
  """
  def sdiffstore(dest, key, keys \\ []), do: ["SDIFFSTORE", dest, key] ++ keys

  @doc ~S"""
  Returns the members of the set resulting from the intersection of all the
  given sets.

  ## Examples

      iex> execute(pid, sadd("key1", ["a", "b", "c"]))
      "3"
      iex> execute(pid, sadd("key2", ["c", "d", "e"]))
      "3"
      iex> execute(pid, sinter("key1")) |> Enum.sort
      ["a", "b", "c"]
      iex> execute(pid, sinter("key1", ["key2"]))
      ["c"]
  """
  def sinter(key, keys \\ []), do: ["SINTER", key] ++ keys

  @doc ~S"""
  Writes the members of the set resulting from the intersection of all the
  given sets to `dest`.

  ## Examples

      iex> execute(pid, sadd("key1", ["a", "b", "c"]))
      "3"
      iex> execute(pid, sadd("key2", ["c", "d", "e"]))
      "3"
      iex> execute(pid, sinterstore("key", "key1"))
      "3"
      iex> execute(pid, smembers("key")) |> Enum.sort
      ["a", "b", "c"]
      iex> execute(pid, sinterstore("key", "key1", ["key2"]))
      "1"
      iex> execute(pid, smembers("key"))
      ["c"]
  """
  def sinterstore(dest, key, keys \\ []), do: ["SINTERSTORE", dest, key] ++ keys

  @doc ~S"""
  Returns if `member` is a member of the set stored at `key`.

  ## Examples

      iex> execute(pid, sadd("myset", "one"))
      "1"
      iex> execute(pid, sismember("myset", "one"))
      "1"
      iex> execute(pid, sismember("myset", "two"))
      "0"
  """
  def sismember(key, member), do: ["SISMEMBER", key, member]

  @doc ~S"""
  Returns all the members of the set value stored at `key`.

  ## Examples

      iex> execute(pid, sadd("myset", ["Hello", "World"]))
      "2"
      iex> execute(pid, smembers("myset")) |> Enum.sort
      ["Hello", "World"]
  """
  def smembers(key), do: ["SMEMBERS", key]

  @doc ~S"""
  Move `member` from the set at `source` to the set at `dest`.

  ## Examples

      iex> execute(pid, sadd("myset", ["one", "two"]))
      "2"
      iex> execute(pid, sadd("myotherset", "three"))
      "1"
      iex> execute(pid, smove("myset", "myotherset", "two"))
      "1"
      iex> execute(pid, smembers("myset"))
      ["one"]
      iex> execute(pid, smembers("myotherset")) |> Enum.sort
      ["three", "two"]
  """
  def smove(source, dest, member), do: ["SMOVE", source, dest, member]

  @doc ~S"""
  Removes and returns one or more random elements from the set value store at
  `key`.

  ## Examples

      iex> execute(pid, sadd("myset", ["one", "two", "three"]))
      "3"
      iex> execute(pid, spop("myset"))
      iex> execute(pid, scard("myset"))
      "2"
  """
  def spop(key), do: ["SPOP", key]

  @doc ~S"""
  Returns one or more random elements from the set value store at
  `key`.

  ## Examples

      iex> execute(pid, sadd("myset", ["one", "two", "three"]))
      "3"
      iex> execute(pid, srandmember("myset")) |> Enum.count
      1
      iex> execute(pid, srandmember("myset", 5)) |> Enum.count
      3
      iex> execute(pid, srandmember("myset", -5)) |> Enum.count
      5
  """
  def srandmember(key, count \\ 1), do: ["SRANDMEMBER", key, count]

  @doc ~S"""
  Remove the specified `members` from the set stored at `key`.

  ## Examples

      iex> execute(pid, sadd("myset", ["one", "two", "three"]))
      "3"
      iex> execute(pid, srem("myset", "one"))
      "1"
      iex> execute(pid, srem("myset", ["three", "four"]))
      "1"
      iex> execute(pid, smembers("myset"))
      ["two"]
  """
  def srem(key, members) when is_list(members), do: ["SREM", key] ++ members
  def srem(key, member), do: srem(key, [member])

  @doc ~S"""
  Incrementally iterate over a collection of elements in a set.

  ## Examples

      iex> execute(pid, sadd("myset", ["1", "2", "3", "foo", "foobar", "feelsgood"]))
      "6"
      iex> execute(pid, sscan("myset", 0, ["MATCH", "f*"])) |> List.last |> Enum.sort
      ["feelsgood", "foo", "foobar"]
  """
  def sscan(key, cursor, options \\ []), do: ["SSCAN", key, cursor] ++ options

  @doc ~S"""
  Returns the members of the set resulting from the union of all the given sets.

  ## Examples

      iex> execute(pid, sadd("key1", ["a", "b", "c"]))
      "3"
      iex> execute(pid, sadd("key2", ["c", "d", "e"]))
      "3"
      iex> execute(pid, sunion("key1")) |> Enum.sort
      ["a", "b", "c"]
      iex> execute(pid, sunion("key1", ["key2"])) |> Enum.sort
      ["a", "b", "c", "d", "e"]
  """
  def sunion(key, keys \\ []), do: ["SUNION", key] ++ keys

  @doc ~S"""
  Write the members of the set resulting from the union of all the given sets to
  `dest`.

  ## Examples

      iex> execute(pid, sadd("key1", ["a", "b", "c"]))
      "3"
      iex> execute(pid, sadd("key2", ["c", "d", "e"]))
      "3"
      iex> execute(pid, sunionstore("key", "key1"))
      "3"
      iex> execute(pid, smembers("key")) |> Enum.sort
      ["a", "b", "c"]
      iex> execute(pid, sunionstore("key", "key1", ["key2"]))
      "5"
      iex> execute(pid, smembers("key")) |> Enum.sort
      ["a", "b", "c", "d", "e"]
  """
  def sunionstore(dest, key, keys \\ []), do: ["SUNIONSTORE", dest, key] ++ keys


  ### SORTED SET OPERATIONS


  @doc ~S"""
  Adds all the specified members with the specified scores to the sorted set
  stored at `key`.

  ## Examples

      iex> execute(pid, zadd("myset", 1, "one"))
      "1"
      iex> execute(pid, zadd("myset", [1, "uno"]))
      "1"
      iex> execute(pid, zadd("myset", [{2, "two"}, {3, "three"}]))
      "2"
      iex> execute(pid, zrange("myset", 0, -1, ["WITHSCORES"]))
      ["one", "1", "uno", "1", "two", "2", "three", "3"]
  """
  def zadd(key, [h|_] = opts) when is_tuple(h), do: zadd(key, opts |> Enum.flat_map(&Tuple.to_list(&1)))
  def zadd(key, opts) when is_list(opts), do: ["ZADD", key] ++ opts
  def zadd(key, score, member), do: zadd(key, [score, member])

  @doc ~S"""
  Returns the number of elements of the sorted set stored at `key`.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}]))
      "2"
      iex> execute(pid, zcard("myset"))
      "2"
  """
  def zcard(key), do: ["ZCARD", key]

  @doc ~S"""
  Returns the number of elements in the sorted set at `key` with a score between
  `min` and `max`.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zcount("myset", "-inf", "+inf"))
      "3"
      iex> execute(pid, zcount("myset", "(1", "3"))
      "2"
  """
  def zcount(key, min, max), do: ["ZCOUNT", key, min, max]

  @doc ~S"""
  Increments the score of `member` in the sorted set stored at `key` by `increment`.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}]))
      "2"
      iex> execute(pid, zincrby("myset", 2, "one"))
      "3"
      iex> execute(pid, zrange("myset", "0", "-1", ["WITHSCORES"]))
      ["two", "2", "one", "3"]
  """
  def zincrby(key, increment, member), do: ["ZINCRBY", key, increment, member]

  @doc ~S"""
  Computes the intersection of the sorted sets given by the specified `keys`,
  and stores the result in `dest`.

  ## Examples

      iex> execute(pid, zadd("set1", [{1, "one"}, {2, "two"}]))
      "2"
      iex> execute(pid, zadd("set2", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zinterstore("out", ["set1", "set2"], ["WEIGHTS", 2, 3]))
      "2"
      iex> execute(pid, zrange("out", "0", "-1", ["WITHSCORES"]))
      ["one", "5", "two", "10"]
  """
  def zinterstore(dest, keys, opts), do: ["ZINTERSTORE", dest, Enum.count(keys)] ++ keys ++ opts

  @doc ~S"""
  Returns the number of elements in the sorted set at `key` with a value between
  `min` and `max`.

  ## Examples

      iex> execute(pid, zadd("myset", [{0, "a"}, {0, "b"}, {0, "c"}, {0, "d"}]))
      "4"
      iex> execute(pid, zlexcount("myset", "-", "+"))
      "4"
      iex> execute(pid, zlexcount("myset", "[b", "[c"))
      "2"
  """
  def zlexcount(key, min, max), do: ["ZLEXCOUNT", key, min, max]

  @doc ~S"""
  Returns the specified range of elements in the sorted set stored at `key`.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zrange("myset", 0, -1))
      ["one", "two", "three"]
      iex> execute(pid, zrange("myset", 2, 3))
      ["three"]
      iex> execute(pid, zrange("myset", -2, -1))
      ["two", "three"]

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zrange("myset", 0, 1, ["WITHSCORES"]))
      ["one", "1", "two", "2"]
  """
  def zrange(key, from, to, opts \\ []), do: ["ZRANGE", key, from, to] ++ opts

  @doc ~S"""
  Returns all the elements in the sorted set at `key` with a value between `min`
  and `max`.

  ## Examples

      iex> execute(pid, zadd("myset", [{0, "a"}, {0, "b"}, {0, "c"}, {0, "d"}]))
      "4"
      iex> execute(pid, zrangebylex("myset", "-", "[c"))
      ["a", "b", "c"]
      iex> execute(pid, zrangebylex("myset", "-", "(c"))
      ["a", "b"]
      iex> execute(pid, zrangebylex("myset", "[aaa", "(d"))
      ["b", "c"]
  """
  def zrangebylex(key, min, max, opts \\ []), do: ["ZRANGEBYLEX", key, min, max] ++ opts

  @doc ~S"""
  Returns all the elements in the sorted set at `key` with a score between `min`
  and `max`.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zrangebyscore("myset", "-inf", "+inf"))
      ["one", "two", "three"]
      iex> execute(pid, zrangebyscore("myset", 1, 2))
      ["one", "two"]
      iex> execute(pid, zrangebyscore("myset", "(1", 2, ["WITHSCORES"]))
      ["two", "2"]
      iex> execute(pid, zrangebyscore("myset", "(1", "(2"))
      []
  """
  def zrangebyscore(key, min, max, opts \\ []), do: ["ZRANGEBYSCORE", key, to_string(min), to_string(max)] ++ opts

  @doc ~S"""
  Returns the rank of `member` in the sorted set stored at `key`.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zrank("myset", "three"))
      "2"
      iex> execute(pid, zrank("myset", "four"))
      :undefined
  """
  def zrank(key, member), do: ["ZRANK", key, member]

  @doc ~S"""
  Removes the specified `members` from the sorted set stored at `key`.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zrem("myset", "two"))
      "1"
      iex> execute(pid, zrange("myset", 0, -1, ["WITHSCORES"]))
      ["one", "1", "three", "3"]
  """
  def zrem(key, members) when is_list(members), do: ["ZREM", key] ++ members
  def zrem(key, member), do: zrem(key, [member])

  @doc ~S"""
  Removes all elements in the sorted set stored at `key` between the
  lexicographical range specified by `min` and `max`.

  ## Examples

      iex> execute(pid, zadd("myset", [{0, "ALPHA"}, {0, "alpha"}, {0, "a"}, {0, "b"}, {0, "y"}, {0, "z"}]))
      "6"
      iex> execute(pid, zremrangebylex("myset", "[alpha", "[omega"))
      "2"
      iex> execute(pid, zrange("myset", 0, -1))
      ["ALPHA", "a", "y", "z"]
  """
  def zremrangebylex(key, min, max), do: ["ZREMRANGEBYLEX", key, min, max]

  @doc ~S"""
  Removes all elements in the sorted set stored at key with rank between `from`
  and `to`.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zremrangebyrank("myset", 0, 1))
      "2"
      iex> execute(pid, zrange("myset", 0, -1, ["WITHSCORES"]))
      ["three", "3"]
  """
  def zremrangebyrank(key, from, to), do: ["ZREMRANGEBYRANK", key, from, to]

  @doc ~S"""
  Removes all elements in the sorted set stored at `key` with a score between
  `min` and `max`.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zremrangebyscore("myset", "-inf", "(2"))
      "1"
      iex> execute(pid, zrange("myset", 0, -1, ["WITHSCORES"]))
      ["two", "2", "three", "3"]
  """
  def zremrangebyscore(key, min, max), do: ["ZREMRANGEBYSCORE", key, min, max]

  @doc ~S"""
  Returns the specified range of elements in the sorted set stored at `key`
  ordered from highest to lowest score.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zrevrange("myset", 0, -1))
      ["three", "two", "one"]
      iex> execute(pid, zrevrange("myset", 2, 3))
      ["one"]
      iex> execute(pid, zrevrange("myset", -2, -1))
      ["two", "one"]
  """
  def zrevrange(key, min, max, opts \\ []), do: ["ZREVRANGE", key, min, max] ++ opts

  @doc ~S"""
  Returns all the elements in the sorted set at `key` with a value between `max`
  and `min` ordered from highest to lowest score.

  ## Examples

      iex> execute(pid, zadd("myset", [{0, "a"}, {0, "b"}, {0, "c"}, {0, "d"}]))
      "4"
      iex> execute(pid, zrevrangebylex("myset", "[c", "-"))
      ["c", "b", "a"]
      iex> execute(pid, zrevrangebylex("myset", "(c", "-"))
      ["b", "a"]
      iex> execute(pid, zrevrangebylex("myset", "(d", "[aaa"))
      ["c", "b"]
  """
  def zrevrangebylex(key, max, min, opts \\ []), do: ["ZREVRANGEBYLEX", key, max, min] ++ opts

  @doc ~S"""
  Returns all the elements in the sorted set at `key` with a score between `max`
  and `min` ordered from highest to lowest score.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zrevrangebyscore("myset", "+inf", "-inf"))
      ["three", "two", "one"]
      iex> execute(pid, zrevrangebyscore("myset", 2, 1))
      ["two", "one"]
      iex> execute(pid, zrevrangebyscore("myset", 2, "(1"))
      ["two"]
      iex> execute(pid, zrevrangebyscore("myset", "(2", "(1"))
      []
  """
  def zrevrangebyscore(key, max, min, opts \\ []), do: ["ZREVRANGEBYSCORE", key, max, min] ++ opts

  @doc ~S"""
  Returns the rank of `member` in the sorted set stored at `key`, with the
  scores ordered from high to low.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zrevrank("myset", "one"))
      "2"
      iex> execute(pid, zrevrank("myset", "four"))
      :undefined
  """
  def zrevrank(key, member), do: ["ZREVRANK", key, member]

  @doc ~S"""
  Incrementally iterate over a collection of elements in a sorted set.

  ## Examples

      iex> execute(pid, zadd("myset", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zscan("myset", 0))
      ["0", ["one", "1", "two", "2", "three", "3"]]
      iex> execute(pid, zscan("myset", 0, ["MATCH", "*o*"]))
      ["0", ["one", "1", "two", "2"]]
  """
  def zscan(key, cursor, opts \\ []), do: ["ZSCAN", key, cursor] ++ opts

  @doc ~S"""
  Returns the score of `member` in the sorted set at `key`.

  ## Examples

      iex> execute(pid, zadd("myset", 1, "one"))
      "1"
      iex> execute(pid, zscore("myset", "one"))
      "1"
  """
  def zscore(key, member), do: ["ZSCORE", key, member]

  @doc ~S"""
  Computes the union of the sorted sets given by the specified `keys`, and
  stores the result in `dest`.

  ## Examples

      iex> execute(pid, zadd("set1", [{1, "one"}, {2, "two"}]))
      "2"
      iex> execute(pid, zadd("set2", [{1, "one"}, {2, "two"}, {3, "three"}]))
      "3"
      iex> execute(pid, zunionstore("out", ["set1", "set2"], ["WEIGHTS", 2, 3]))
      "3"
      iex> execute(pid, zrange("out", "0", "-1", ["WITHSCORES"]))
      ["one", "5", "three", "9", "two", "10"]
  """
  def zunionstore(dest, keys, opts), do: ["ZUNIONSTORE", dest, Enum.count(keys)] ++ keys ++ opts


  ### HASH OPERATIONS




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
