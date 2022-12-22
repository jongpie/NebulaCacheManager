public without sharing class CacheManager {
  @TestVisible
  private static final List<CacheValue__mdt> DECLARATIVE_CACHED_VALUES = CacheValue__mdt.getAll().values();
  @TestVisible
  private static final String PLATFORM_CACHE_NULL_VALUE = '<{(CACHE_VALUE_IS_NULL)}>'; // Presumably, no one will ever use this as an actual value
  private static final CacheConfiguration__mdt ORGANIZATION_CACHE_CONFIGURATION = CacheConfiguration__mdt.getInstance('Organization');
  private static final CacheConfiguration__mdt SESSION_CACHE_CONFIGURATION = CacheConfiguration__mdt.getInstance('Session');
  private static final CacheConfiguration__mdt TRANSACTION_CACHE_CONFIGURATION = CacheConfiguration__mdt.getInstance('Transaction');

  private static PlatformCache organizationCacheInstance;
  private static PlatformCachePartitionDelegate organizationPartitionDelegate;
  private static PlatformCache sessionCacheInstance;
  private static PlatformCachePartitionDelegate sessionPartitionDelegate;
  private static TransactionCache transactionCacheInstance;

  @TestVisible
  private enum PlatformCachePartitionType {
    ORGANIZATION,
    SESSION
  }

  public interface Cacheable {
    Boolean isEnabled();
    Boolean isImmutable();
    Set<String> getKeys();
    Boolean contains(String key);
    Object get(String key);
    void put(String key, Object value);
    void remove(String key);
    void removeAll();
  }

  public static Cacheable getOrganizationCache() {
    if (organizationPartitionDelegate == null) {
      organizationPartitionDelegate = new PlatformCachePartitionDelegate(
        PlatformCachePartitionType.ORGANIZATION,
        ORGANIZATION_CACHE_CONFIGURATION.PlatformCachePartitionName__c
      );
    }

    if (organizationCacheInstance == null) {
      organizationCacheInstance = new PlatformCache(ORGANIZATION_CACHE_CONFIGURATION, getTransactionCache(), organizationPartitionDelegate);
    }

    return organizationCacheInstance;
  }

  public static Cacheable getSessionCache() {
    if (sessionPartitionDelegate == null) {
      sessionPartitionDelegate = new PlatformCachePartitionDelegate(
        PlatformCachePartitionType.SESSION,
        SESSION_CACHE_CONFIGURATION.PlatformCachePartitionName__c
      );
    }

    if (sessionCacheInstance == null) {
      sessionCacheInstance = new PlatformCache(SESSION_CACHE_CONFIGURATION, getTransactionCache(), sessionPartitionDelegate);
    }

    return sessionCacheInstance;
  }

  public static Cacheable getTransactionCache() {
    if (transactionCacheInstance == null) {
      transactionCacheInstance = new TransactionCache(TRANSACTION_CACHE_CONFIGURATION);
    }
    return transactionCacheInstance;
  }

  // @TestVisible
  // private static void setMockOrganizationPartitionDelegate(PlatformCachePartitionDelegate mockOrganizationPartitionDelegate) {
  //   organizationPartitionDelegate = mockOrganizationPartitionDelegate;
  // }

  // @TestVisible
  // private static void setMockSessionPartitionDelegate(PlatformCachePartitionDelegate mockSessionPartitionDelegate) {
  //   sessionPartitionDelegate = mockSessionPartitionDelegate;
  // }

  @SuppressWarnings('PMD.ApexDoc')
  private class PlatformCache implements Cacheable {
    private final PlatformCachePartitionDelegate cachePartitionDelegate;
    private final Integer cacheTtlSeconds;
    private final CacheConfiguration__mdt configuration;
    private final Cacheable transactionCache;

    private PlatformCache(CacheConfiguration__mdt configuration, Cacheable transactionCache, PlatformCachePartitionDelegate cachePartitionDelegate) {
      this.configuration = configuration;
      this.transactionCache = transactionCache;
      this.cachePartitionDelegate = cachePartitionDelegate;
    }

    public Boolean isEnabled() {
      return this.configuration.IsEnabled__c;
    }

    public Boolean isImmutable() {
      return this.configuration.IsImmutable__c;
    }

    public Set<String> getKeys() {
      return this.cachePartitionDelegate.getKeys();
    }

    public Boolean contains(String key) {
      if (this.configuration.IsEnabled__c == false || this.transactionCache.contains(key) || this.cachePartitionDelegate.isAvailable() == false) {
        return this.transactionCache.contains(key);
      } else {
        return this.cachePartitionDelegate.contains(key);
      }
    }

    public Object get(String key) {
      if (this.transactionCache.contains(key) || this.cachePartitionDelegate.isAvailable() == false) {
        return this.transactionCache.get(key);
      } else {
        Object value = this.cachePartitionDelegate.get(key);
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

      // TODO add check for this.configuration.IsImmutable__c == false + this.contains(key)
      if (this.configuration.IsEnabled__c && this.cachePartitionDelegate.isAvailable() == true) {
        // Platform cache does not support storing null values, so a predefined value is used as a substitute
        if (value == null) {
          value = PLATFORM_CACHE_NULL_VALUE;
        }
        Cache.Visibility visibility = Cache.Visibility.valueOf(this.configuration.PlatformCacheVisibility__c.toUpperCase());
        this.cachePartitionDelegate.put(key, value, this.configuration.PlatformCacheTimeToLive__c.intValue(), visibility, this.configuration.IsImmutable__c);
      }
    }

    public void remove(String key) {
      if (this.configuration.IsImmutable__c == true) {
        return;
      }

      this.transactionCache.remove(key);

      if (this.configuration.IsEnabled__c == true && this.cachePartitionDelegate.isAvailable() == true) {
        this.cachePartitionDelegate.remove(key);
      }
    }

    public void removeAll() {
      if (this.configuration.IsEnabled__c == true && this.cachePartitionDelegate.isAvailable() == true) {
        this.cachePartitionDelegate.removeAll();
      }
    }
  }

  private class TransactionCache implements Cacheable {
    private final CacheConfiguration__mdt configuration;
    private final Map<String, Object> keyToValue = new Map<String, Object>();

    private TransactionCache(CacheConfiguration__mdt configuration) {
      this.configuration = configuration;
      this.loadDeclarativeCacheValues();
    }

    public virtual Boolean isEnabled() {
      return this.configuration.IsEnabled__c;
    }

    public virtual Boolean isImmutable() {
      return this.configuration.IsImmutable__c;
    }

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
      if (this.configuration.IsEnabled__c == true || (this.configuration.IsImmutable__c == false || this.contains(key) == false)) {
        this.keyToValue.put(key, value);
      }
    }

    public void remove(String key) {
      if (this.configuration.IsEnabled__c == true && this.configuration.IsImmutable__c == false) {
        this.keyToValue.remove(key);
      }
    }

    public void removeAll() {
      if (this.configuration.IsEnabled__c == true) {
        this.keyToValue.clear();
      }
    }

    private void loadDeclarativeCacheValues() {
      for (CacheValue__mdt declarativeCacheValue : DECLARATIVE_CACHED_VALUES) {
        this.keyToValue.put(declarativeCacheValue.DeveloperName, declarativeCacheValue.Value__c);
      }
    }
  }

  // Platform Cache proxy/delegate class
  @TestVisible
  private virtual class PlatformCachePartitionDelegate {
    private final Cache.Partition platformCachePartition;

    protected PlatformCachePartitionDelegate(PlatformCachePartitionType partitionType, String partitionName) {
      // Since orgs can customize the platform cache partition (via CacheConfiguration__mdt.PlatformCachePartitionName__c),
      // some orgs could have problematic configurations (or may have even deleted the referenced partition),
      // and it seems better to eat the exceptions & fallback to the transaction cache (which doesn't rely on Platform Cache).
      // The alternative is a runtime exception, which isn't ideal.
      try {
        switch on partitionType {
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

    public virtual Set<String> getKeys() {
      return this.platformCachePartition.getKeys();
    }

    public virtual Boolean contains(String key) {
      return this.platformCachePartition != null && this.platformCachePartition.contains(key);
    }

    public virtual Object get(String key) {
      return this.platformCachePartition?.get(key);
    }

    public virtual Boolean isAvailable() {
      return this.platformCachePartition != null && this.platformCachePartition.isAvailable();
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public virtual void put(String key, Object value, Integer cacheTtlSeconds, Cache.Visibility cacheVisiblity, Boolean isCacheImmutable) {
      this.platformCachePartition?.put(key, value, cacheTtlSeconds, cacheVisiblity, isCacheImmutable);
    }

    public virtual void remove(String key) {
      this.platformCachePartition?.remove(key);
    }

    public void removeAll() {
      for (String key : this.platformCachePartition?.getKeys()) {
        this.platformCachePartition.remove(key);
      }
    }
  }
}
