defmodule HotspotApi.Cache do
  @moduledoc """
  Caching layer for frequently accessed data using ETS (Erlang Term Storage).
  Provides in-memory caching with TTL support for performance optimization.
  """

  use GenServer
  require Logger

  @table_name :hotspot_cache
  @default_ttl :timer.minutes(5)

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Get a value from cache. Returns {:ok, value} or :error if not found or expired.
  """
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expires_at}] ->
        if System.system_time(:millisecond) < expires_at do
          {:ok, value}
        else
          delete(key)
          :error
        end

      [] ->
        :error
    end
  end

  @doc """
  Put a value in cache with optional TTL in milliseconds.
  """
  def put(key, value, ttl \\ @default_ttl) do
    expires_at = System.system_time(:millisecond) + ttl
    :ets.insert(@table_name, {key, value, expires_at})
    :ok
  end

  @doc """
  Delete a value from cache.
  """
  def delete(key) do
    :ets.delete(@table_name, key)
    :ok
  end

  @doc """
  Get or compute a value. If key exists in cache, return it.
  Otherwise, execute the function, cache the result, and return it.
  """
  def fetch(key, fun, ttl \\ @default_ttl) do
    case get(key) do
      {:ok, value} ->
        value

      :error ->
        value = fun.()
        put(key, value, ttl)
        value
    end
  end

  @doc """
  Clear all cache entries.
  """
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  @doc """
  Get cache statistics.
  """
  def stats do
    size = :ets.info(@table_name, :size)
    memory = :ets.info(@table_name, :memory)

    %{
      entries: size,
      memory_words: memory,
      memory_bytes: memory * :erlang.system_info(:wordsize)
    }
  end

  # Server Callbacks

  @impl true
  def init(_) do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])

    # Schedule periodic cleanup of expired entries
    schedule_cleanup()

    Logger.info("Cache initialized with table: #{@table_name}")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private Functions

  defp schedule_cleanup do
    # Run cleanup every 5 minutes
    Process.send_after(self(), :cleanup, :timer.minutes(5))
  end

  defp cleanup_expired_entries do
    now = System.system_time(:millisecond)

    expired_keys =
      :ets.select(@table_name, [
        {{:"$1", :"$2", :"$3"}, [{:<, :"$3", now}], [:"$1"]}
      ])

    Enum.each(expired_keys, &:ets.delete(@table_name, &1))

    if length(expired_keys) > 0 do
      Logger.debug("Cleaned up #{length(expired_keys)} expired cache entries")
    end
  end
end
