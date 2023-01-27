public without sharing class CacheManager_v5_partition_proxy {
  @TestVisible
  private static final String PLATFORM_CACHE_NULL_VALUE = '<{(CACHE_VALUE_IS_NULL)}>'; // Presumably, no one will ever use this as an actual value

  private static PlatformCache organizationCacheInstance;
  private static PlatformCache sessionCacheInstance;
  private static TransactionCache transactionCacheInstance;

  private enum PlatformCacheType {
    ORGANIZATION,
    SESSION
  }

  public interface Cacheable {
    Boolean contains(String key);
    Object get(String key);
    Boolean isAvailable();
    void put(String key, Object value);
    void remove(String key);
  }

  public static Cacheable getOrganizationCache() {
    if (sessionCacheInstance == null) {
      Integer organizationCacheTtlSeconds = 86400; // 86,400 seconds == 24 hours, the max time-to-live (TTL) allowed for org cache
      // For now, the partition name is hardcoded 😭 But we'll revisit this soon!
      PlatformCachePartitionProxy partitionProxy = new PlatformCachePartitionProxy(PlatformCacheType.SESSION, 'CacheManager');
      sessionCacheInstance = getPlatformCache(new TransactionCache(), partitionProxy, organizationCacheTtlSeconds);
    }
    return sessionCacheInstance;
  }

  public static Cacheable getSessionCache() {
    if (sessionCacheInstance == null) {
      Integer sessionCacheTtlSeconds = 28800; // 28,800 seconds == 8 hours, the max time-to-live (TTL) allowed for session cache
      // For now, the partition name is hardcoded 😭 But we'll revisit this soon!
      PlatformCachePartitionProxy partitionProxy = new PlatformCachePartitionProxy(PlatformCacheType.SESSION, 'CacheManager');
      sessionCacheInstance = getPlatformCache(new TransactionCache(), partitionProxy, sessionCacheTtlSeconds);
    }
    return sessionCacheInstance;
  }

  public static Cacheable getTransactionCache() {
    if (transactionCacheInstance == null) {
      transactionCacheInstance = new TransactionCache();
    }

    return transactionCacheInstance;
  }

  private static void validateKey(String key) {
    Pattern alphanumericPattern = Pattern.compile('^[a-zA-Z0-9]+$');
    Matcher regexMatcher = alphanumericPattern.matcher(key);
    if (regexMatcher.matches() == false) {
      throw new IllegalArgumentException('Key must be alphanumeric, received key: ' + key);
    }
  }

  private static PlatformCache getPlatformCache(TransactionCache localTransactionCache, PlatformCachePartitionProxy partitionProxy, Integer cacheTtlSeconds) {
    PlatformCache platformCache = new PlatformCache(localTransactionCache, partitionProxy, cacheTtlSeconds);

    return platformCache;
  }

  private class PlatformCache implements Cacheable {
    private final PlatformCachePartitionProxy cachePartitionProxy;
    private final Integer cacheTtlSeconds;
    private final TransactionCache fallbackTransactionCache;

    private PlatformCache(TransactionCache transactionCache, PlatformCachePartitionProxy cachePartitionProxy, Integer cacheTtlSeconds) {
      this.fallbackTransactionCache = transactionCache;
      this.cachePartitionProxy = cachePartitionProxy;
      this.cacheTtlSeconds = cacheTtlSeconds;
    }

    public Boolean contains(String key) {
      if (this.fallbackTransactionCache.contains(key) == true || this.cachePartitionProxy.isAvailable() == false) {
        return this.fallbackTransactionCache.contains(key);
      } else {
        return this.cachePartitionProxy.contains(key);
      }
    }

    public Object get(String key) {
      if (this.fallbackTransactionCache.contains(key) || this.cachePartitionProxy.isAvailable() == false) {
        return this.fallbackTransactionCache.get(key);
      } else {
        Object value = this.cachePartitionProxy.get(key);
        // Platform cache does not support storing null values, so a predefined value is used as a substitute
        if (value == PLATFORM_CACHE_NULL_VALUE) {
          value = null;
        }
        this.fallbackTransactionCache.put(key, value);
        return value;
      }
    }

    public Boolean isAvailable() {
      return this.cachePartitionProxy.isAvailable() == true;
    }

    public void put(String key, Object value) {
      validateKey(key);
      this.fallbackTransactionCache.put(key, value);

      // Platform cache does not support storing null values, so a predefined value is used as a substitute
      if (value == null) {
        value = PLATFORM_CACHE_NULL_VALUE;
      }
      Cache.Visibility visibility = Cache.Visibility.ALL;
      Boolean isImmutable = false;
      this.cachePartitionProxy.put(key, value, this.cacheTtlSeconds, visibility, isImmutable);
    }

    public void remove(String key) {
      this.fallbackTransactionCache.remove(key);
      if (this.isAvailable() == true) {
        this.cachePartitionProxy.remove(key);
      }
    }
  }

  @TestVisible
  private virtual class PlatformCachePartitionProxy {
    private final Cache.Partition platformCachePartition;

    protected PlatformCachePartitionProxy(PlatformCacheType cacheType, String partitionName) {
      // If the specified partition name is not found, the platform automatically throws a runtime exception, which isn't ideal.
      // It seems better to eat the exceptions & fallback to the transaction cache (which doesn't rely on Platform Cache).
      try {
        switch on cacheType {
          when ORGANIZATION {
            this.platformCachePartition = Cache.Org.getPartition(partitionName);
          }
          when SESSION {
            this.platformCachePartition = Cache.Session.getPartition(partitionName);
          }
        }
      } catch (Cache.Org.OrgCacheException orgCacheException) {
        // No-op if the partition can't be found - the rest of the code will fallback to using the transaction cache
      } catch (Cache.Session.SessionCacheException sessionCacheException) {
        // No-op if the partition can't be found - the rest of the code will fallback to using the transaction cache
      }
    }

    public virtual Boolean contains(String key) {
      return this.platformCachePartition?.contains(key) == true;
    }

    public virtual Object get(String key) {
      return this.platformCachePartition?.get(key);
    }

    public virtual Boolean isAvailable() {
      return this.platformCachePartition?.isAvailable() == true;
    }

    public virtual void put(String key, Object value, Integer cacheTtlSeconds, Cache.Visibility cacheVisiblity, Boolean isCacheImmutable) {
      this.platformCachePartition?.put(key, value, cacheTtlSeconds, cacheVisiblity, isCacheImmutable);
    }

    public virtual void remove(String key) {
      this.platformCachePartition?.remove(key);
    }
  }

  private class TransactionCache implements Cacheable {
    private final CacheConfiguration__mdt configuration;
    private final Map<String, Object> keyToValue = new Map<String, Object>();

    public Boolean contains(String key) {
      return this.keyToValue.containsKey(key);
    }

    public Object get(String key) {
      return this.keyToValue.get(key);
    }

    public Boolean isAvailable() {
      return true;
    }

    public void put(String key, Object value) {
      validateKey(key);
      this.keyToValue.put(key, value);
    }

    public void remove(String key) {
      this.keyToValue.remove(key);
    }
  }
}
