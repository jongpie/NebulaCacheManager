public class CacheManager_with_platform_cache {
  private static final String PLATFORM_CACHE_NULL_VALUE = '<{(CACHE_VALUE_IS_NULL)}>'; // Presumably, no one will ever use this as an actual value

  // Private singleton instances of org, session, and transaction caches
  private static PlatformCache organizationCacheInstance;
  private static PlatformCache sessionCacheInstance;
  private static TransactionCache transactionCache;

  public interface Cacheable {
    Set<String> getKeys();
    Boolean contains(String key);
    Object get(String key);
    void put(String key, Object value);
    void remove(String key);
    void removeAll();
  }

  public static Cacheable getOrganizationCache() {
    if (organizationCacheInstance == null) {
      // For now, the partition name is hardcoded 😭 But we'll revisit this soon!
      Cache.Partition organizationPartition = Cache.Org.getPartition('SamplePartition');
      organizationCacheInstance = new PlatformCache(organizationPartition, getTransactionCache());
    }

    return organizationCacheInstance;
  }

  public static Cacheable getSessionCache() {
    if (sessionCacheInstance == null) {
      // For now, the partition name is hardcoded 😭 But we'll revisit this soon!
      Cache.Partition sessionPartition = Cache.Session.getPartition('SamplePartition');
      sessionCacheInstance = new PlatformCache(sessionPartition, getTransactionCache());
    }

    return sessionCacheInstance;
  }

  public static Cacheable getTransactionCache() {
    if (transactionCache == null) {
      transactionCache = new TransactionCache();
    }

    return transactionCache;
  }

  private class PlatformCache implements Cacheable {
    private final Cache.Partition platformCachePartition;
    private final Boolean cacheIsImmutable = true;
    private final Integer cacheTtlSeconds;
    private final Cache.Visibility cacheVisibility = Cache.Visibility.All;
    private final Cacheable transactionCache;

    private PlatformCache(Cache.Partition platformCachePartition, Cacheable transactionCache) {
      this.transactionCache = transactionCache;
      this.platformCachePartition = platformCachePartition;
    }

    public Set<String> getKeys() {
      return this.platformCachePartition.getKeys();
    }

    public Boolean contains(String key) {
      if (this.transactionCache.contains(key) || this.platformCachePartition.isAvailable() == false) {
        return this.transactionCache.contains(key);
      } else {
        return this.platformCachePartition.contains(key);
      }
    }

    public Object get(String key) {
      if (this.transactionCache.contains(key) || this.platformCachePartition.isAvailable() == false) {
        return this.transactionCache.get(key);
      } else {
        Object value = this.platformCachePartition.get(key);
        // Platform cache does not support storing null values, so a predefined value is used as a substitute
        if (value == PLATFORM_CACHE_NULL_VALUE) {
          value = null;
        }
        this.transactionCache.put(key, value);
        return value;
      }
    }

    public void put(String key, Object value) {
      this.transactionCache.put(key, value);

      if (this.platformCachePartition.isAvailable() == true) {
        // Platform cache does not support storing null values, so a predefined value is used as a substitute
        if (value == null) {
          value = PLATFORM_CACHE_NULL_VALUE;
        }

        this.platformCachePartition.put(key, value, this.cacheTtlSeconds, this.cacheVisibility, this.cacheIsImmutable);
      }
    }

    public void remove(String key) {
      this.transactionCache.remove(key);

      if (this.platformCachePartition.isAvailable() == true) {
        this.platformCachePartition.remove(key);
      }
    }

    public void removeAll() {
      if (this.platformCachePartition.isAvailable() == true) {
        for (String key : this.getKeys()) {
          this.platformCachePartition.remove(key);
        }
      }
    }
  }

  private class TransactionCache implements Cacheable {
    private final Map<String, Object> keyToValue = new Map<String, Object>();

    public Set<String> getKeys() {
      return this.keyToValue.keySet();
    }

    public Boolean contains(String key) {
      return this.keyToValue.containsKey(key);
    }

    public Object get(String key) {
      return this.keyToValue.get(key);
    }

    public void put(String key, Object value) {
      this.keyToValue.put(key, value);
    }

    public void remove(String key) {
      this.keyToValue.remove(key);
    }

    public void removeAll() {
      this.keyToValue.clear();
    }
  }
}
