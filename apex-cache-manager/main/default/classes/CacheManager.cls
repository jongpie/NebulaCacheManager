public without sharing class CacheManager {
  // TODO finish implementing this, to support dynamic/multiple platform cache partiitions
  private static final Map<String, Cacheable> CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE = new Map<String, Cacheable>();
  // private static final Map<CacheType, Cacheable> CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE = new Map<String, Cacheable>();

  // TODO solidify approach for mocking CacheConfiguration__mdt & CacheValue__mdt records
  @TestVisible
  private static final List<CacheValue__mdt> DECLARATIVE_CACHE_VALUES = Schema.CacheValue__mdt.getAll().values();
  @TestVisible
  private static final String PLATFORM_CACHE_NULL_VALUE = '<{(CACHE_VALUE_IS_NULL)}>'; // Presumably, no one will ever use this as an actual value
  private static final CacheConfiguration__mdt ORGANIZATION_CACHE_CONFIGURATION = Schema.CacheConfiguration__mdt.getInstance('Organization');
  private static final CacheConfiguration__mdt SESSION_CACHE_CONFIGURATION = Schema.CacheConfiguration__mdt.getInstance('Session');
  private static final CacheConfiguration__mdt TRANSACTION_CACHE_CONFIGURATION = Schema.CacheConfiguration__mdt.getInstance('Transaction');

  // TODO eliminate / switch to using CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE
  private static PlatformCache orgCacheInstance;

  // TODO promote to top-level class?
  public enum CacheType {
    ORGANIZATION_PLATFORM_CACHE,
    SESSION_PLATFORM_CACHE,
    TRANSACTION_CACHE
  }

  public interface Cacheable {
    Boolean contains(String key);
    Set<String> getKeys();
    Object get(String key);
    Map<String, Object> get(Set<String> keys);
    Map<String, Object> getAll();
    Boolean isAvailable();
    Boolean isEnabled();
    Boolean isImmutable();
    void put(String key, Object value);
    void putAll(Map<String, Object> keyToValue);
    void remove(String key);
    void removeAll();
  }

  // public static Cacheable getCache(CacheType type) {
  //   switch on type {
  //     when ORGANIZATION_PLATFORM_CACHE {
  //       return getOrganizationCache();
  //     }
  //     when SESSION_PLATFORM_CACHE {
  //       return getSessionCache();
  //     }
  //     when TRANSACTION_CACHE {
  //       return getTransactionCache();
  //     }
  //     when else {
  //       return null;
  //     }
  //   }
  // }

  // public static Cacheable getCache(CacheType type, CacheConfiguration__mdt configuration) {
  //   switch on type {
  //     when ORGANIZATION_PLATFORM_CACHE {
  //       // return getPlatformCache(configuration, CacheType.ORGANIZATION_PLATFORM_CACHE);
  //       return getOrganizationCache(configuration);
  //     }
  //     when SESSION_PLATFORM_CACHE {
  //       return getSessionCache(configuration);
  //     }
  //     when TRANSACTION_CACHE {
  //       // return getTransactionCache(configuration);
  //       return getTransactionCache();
  //     }
  //     when else {
  //       return null;
  //     }
  //   }
  // }

  public static Cacheable getOrganizationCache() {
    return getOrganizationCache(ORGANIZATION_CACHE_CONFIGURATION);
  }

  public static Cacheable getOrganizationCache(String cachePartitionName) {
    CacheConfiguration__mdt defaultConfiguration = ORGANIZATION_CACHE_CONFIGURATION.clone();
    defaultConfiguration.DeveloperName = cachePartitionName;
    defaultConfiguration.PlatformCachePartitionName__c = cachePartitionName;
    return getOrganizationCache(defaultConfiguration);
  }

  public static Cacheable getOrganizationCache(CacheConfiguration__mdt configuration) {
    return getPlatformCache(configuration, CacheType.ORGANIZATION_PLATFORM_CACHE);
  }

  public static Cacheable getSessionCache() {
    return getSessionCache(SESSION_CACHE_CONFIGURATION);
  }

  public static Cacheable getSessionCache(String cachePartitionName) {
    CacheConfiguration__mdt defaultConfiguration = SESSION_CACHE_CONFIGURATION.clone();
    defaultConfiguration.DeveloperName = cachePartitionName;
    defaultConfiguration.PlatformCachePartitionName__c = cachePartitionName;
    return getSessionCache(defaultConfiguration);
  }

  public static Cacheable getSessionCache(CacheConfiguration__mdt configuration) {
    return getPlatformCache(configuration, CacheType.SESSION_PLATFORM_CACHE);
  }

  public static Cacheable getTransactionCache() {
    if (CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.containsKey(TRANSACTION_CACHE_CONFIGURATION.DeveloperName)) {
      return CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.get(TRANSACTION_CACHE_CONFIGURATION.DeveloperName);
    }

    TransactionCache transactionCacheInstance = new TransactionCache(TRANSACTION_CACHE_CONFIGURATION);
    CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.put(TRANSACTION_CACHE_CONFIGURATION.DeveloperName, transactionCacheInstance);

    return transactionCacheInstance;
  }

  private static void validateKey(String key) {
    Pattern targetPattern = Pattern.compile('^[a-zA-Z0-9]+$');

    Matcher regexMatcher = targetPattern.matcher(key);
    if (regexMatcher.matches() == false) {
      throw new IllegalArgumentException('Key must be alphanumeric, received key: ' + key);
    }
  }

  private static Cacheable getPlatformCache(CacheConfiguration__mdt configuration, CacheType platformCacheType) {
    if (CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.containsKey(configuration.DeveloperName)) {
      return CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.get(configuration.DeveloperName);
    }

    PlatformCachePartitionProxy partitionProxy = new PlatformCachePartitionProxy(platformCacheType, configuration.PlatformCachePartitionName__c);
    CacheConfiguration__mdt localTransactionCacheConfiguration = new CacheConfiguration__mdt(
      IsEnabled__c = true,
      IsImmutable__c = configuration.IsImmutable__c
    );

    // TODO finish implementation to use this below
    PlatformCache platformCache = new PlatformCache(configuration, new TransactionCache(localTransactionCacheConfiguration), partitionProxy);
    CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.put(configuration.DeveloperName, platformCache);

    return platformCache;
  }

  private static Map<String, Object> loadDeclarativeCacheValues(CacheConfiguration__mdt cacheConfiguration) {
    Map<String, Object> keyToCacheValue = new Map<String, Object>();
    if (cacheConfiguration.IsEnabled__c == false || cacheConfiguration.Id == null) {
      return keyToCacheValue;
    }

    for (CacheValue__mdt declarativeCacheValue : DECLARATIVE_CACHE_VALUES) {
      if (declarativeCacheValue.Cache__c == cacheConfiguration.Id && declarativeCacheValue.IsEnabled__c == true) {
        System.Type dataType = System.Type.forName(declarativeCacheValue.DataType__c);
        System.debug('>>> data type: ' + dataType);
        Boolean isString = declarativeCacheValue.DataType__c == String.class.getName();
        Object castedValue = isString ? declarativeCacheValue.Value__c : JSON.deserialize(declarativeCacheValue.Value__c, dataType);
        System.debug('>>> data value: ' + castedValue);
        keyToCacheValue.put(declarativeCacheValue.Key__c, castedValue);
      }
    }
    System.debug('>>> keyToCacheValue: ' + keyToCacheValue);
    return keyToCacheValue;
  }

  @SuppressWarnings('PMD.ApexDoc')
  private class PlatformCache implements Cacheable {
    private final PlatformCachePartitionProxy cachePartitionProxy;
    private final Integer cacheTtlSeconds;
    private final CacheConfiguration__mdt configuration;
    private final transactionCache transactionCache;

    private PlatformCache(CacheConfiguration__mdt configuration, transactionCache transactionCache, PlatformCachePartitionProxy cachePartitionProxy) {
      this.configuration = configuration;
      this.transactionCache = transactionCache;
      this.cachePartitionProxy = cachePartitionProxy;

      this.putAll(loadDeclarativeCacheValues(this.configuration));
    }

    public Boolean contains(String key) {
      if (this.configuration.IsEnabled__c == false || this.transactionCache.contains(key) || this.cachePartitionProxy.isAvailable() == false) {
        return this.transactionCache.contains(key);
      } else {
        return this.cachePartitionProxy.contains(key);
      }
    }

    public Set<String> getKeys() {
      Set<String> keys = new Set<String>();
      keys.addAll(this.transactionCache.getKeys());
      keys.addAll(this.cachePartitionProxy.getKeys());
      return keys;
    }

    public Object get(String key) {
      if (this.transactionCache.contains(key) || this.cachePartitionProxy.isAvailable() == false) {
        return this.transactionCache.get(key);
      } else {
        Object value = this.cachePartitionProxy.get(key);
        // Platform cache does not support storing null values, so a predefined value is used as a substitute
        if (value == PLATFORM_CACHE_NULL_VALUE) {
          value = null;
        }
        this.transactionCache.put(key, value);
        return value;
      }
    }

    public Map<String, Object> get(Set<String> keys) {
      return this.cachePartitionProxy.get(keys);
    }

    public Map<String, Object> getAll() {
      return this.get(this.getKeys());
    }

    public Boolean isAvailable() {
      return this.isEnabled() && this.cachePartitionProxy?.isAvailable() == true;
    }

    public Boolean isEnabled() {
      return this.configuration?.IsEnabled__c == true;
    }

    public Boolean isImmutable() {
      return this.configuration?.IsImmutable__c == true;
    }

    public void put(String key, Object value) {
      if (this.isEnabled() == false) {
        return;
      }

      validateKey(key);

      this.transactionCache.put(key, value);

      // TODO add check for this.configuration.IsImmutable__c == false + this.contains(key)
      if (this.isAvailable() == true) {
        // Platform cache does not support storing null values, so a predefined value is used as a substitute
        if (value == null) {
          value = PLATFORM_CACHE_NULL_VALUE;
        }
        Cache.Visibility visibility = Cache.Visibility.valueOf(this.configuration.PlatformCacheVisibility__c.toUpperCase());
        this.cachePartitionProxy.put(key, value, this.configuration.PlatformCacheTimeToLive__c.intValue(), visibility, this.configuration.IsImmutable__c);
      }
    }

    public void putAll(Map<String, Object> keyToValue) {
      for (String key : keyToValue.keySet()) {
        this.put(key, keyToValue.get(key));
      }
    }

    public void remove(String key) {
      if (this.configuration.IsImmutable__c == true) {
        return;
      }

      this.transactionCache.remove(key);

      if (this.configuration.IsEnabled__c == true && this.cachePartitionProxy.isAvailable() == true) {
        this.cachePartitionProxy.remove(key);
      }
    }

    public void removeAll() {
      if (this.configuration.IsEnabled__c == true && this.cachePartitionProxy.isAvailable() == true) {
        this.cachePartitionProxy.removeAll();
      }
    }
  }

  private class TransactionCache implements Cacheable {
    private final CacheConfiguration__mdt configuration;
    private final Map<String, Object> keyToValue = new Map<String, Object>();

    private TransactionCache(CacheConfiguration__mdt configuration) {
      this.configuration = configuration;

      this.putAll(loadDeclarativeCacheValues(this.configuration));
    }

    public Boolean contains(String key) {
      return this.keyToValue.containsKey(key);
    }

    public Set<String> getKeys() {
      return this.keyToValue.keySet();
    }

    public Object get(String key) {
      return this.keyToValue.get(key);
    }

    public Map<String, Object> get(Set<String> keys) {
      Map<String, Object> matchingKeyToValue = new Map<String, Object>();
      for (String key : keys) {
        matchingKeyToValue.put(key, this.get(key));
      }
      return matchingKeyToValue;
    }

    public Map<String, Object> getAll() {
      return this.keyToValue.clone();
    }

    public Boolean isAvailable() {
      return this.isEnabled() == true;
    }

    public Boolean isEnabled() {
      return this.configuration?.IsEnabled__c == true;
    }

    public Boolean isImmutable() {
      return this.configuration?.IsImmutable__c == true;
    }

    public void put(String key, Object value) {
      if (this.isEnabled() == true || (this.isImmutable() == false || this.contains(key) == false)) {
        validateKey(key);
        this.keyToValue.put(key, value);
      }
    }

    public void putAll(Map<String, Object> keyToValue) {
      for (String key : keyToValue.keySet()) {
        this.put(key, keyToValue.get(key));
      }
    }

    public void remove(String key) {
      if (this.isEnabled() == true && this.isImmutable() == false) {
        this.keyToValue.remove(key);
      }
    }

    public void removeAll() {
      if (this.isEnabled() == true) {
        this.keyToValue.clear();
      }
    }
  }

  // Platform Cache proxy class
  @TestVisible
  private virtual class PlatformCachePartitionProxy {
    private final Cache.Partition platformCachePartition;

    protected PlatformCachePartitionProxy(CacheType platformCacheType, String partitionName) {
      // Since orgs can customize the platform cache partition (via CacheConfiguration__mdt.PlatformCachePartitionName__c),
      // some orgs could have problematic configurations (or may have even deleted the referenced partition),
      // and it seems better to eat the exceptions & fallback to the transaction cache (which doesn't rely on Platform Cache).
      // The alternative is a runtime exception, which isn't ideal.
      try {
        switch on platformCacheType {
          when ORGANIZATION_PLATFORM_CACHE {
            this.platformCachePartition = Cache.Org.getPartition(partitionName);
          }
          when SESSION_PLATFORM_CACHE {
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
      return this.platformCachePartition != null && this.platformCachePartition.contains(key);
    }

    public virtual Set<String> getKeys() {
      return this.platformCachePartition.getKeys();
    }

    public virtual Object get(String key) {
      return this.platformCachePartition?.get(key);
    }

    public virtual Map<String, Object> get(Set<String> keys) {
      return this.isAvailable() == false ? new Map<String, Object>() : this.platformCachePartition.get(keys);
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
