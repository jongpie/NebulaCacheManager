---
title: 'Joys of Apex: Iteratively Building a Flexible Caching System'
description: 'TODO'
keywords: 'salesforce.com, SFDC, apex, caching, platform cache'
image: './joys-of-apex.png'
date: ''
---

# Iteratively Building a Flexible Caching System

TODO intro paragraph, and either here or at the end, add link to a new public github repo containing full code (2 folders, 1 for cache system, and 1 for example usage)

## Overview - What kind of caching are we discussing?

Discuss how constants & static variables work in Apex (only lasts for the duration of a transaction [as defined by Salesforce](source))

- related links
  - [Developer Guide: Apex Transactions](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_transaction.htm)

TODO - for caching query results & other data that doesn't frequently change, in one of these:

1. Single Apex transaction
2. Single user session
3. Org-wide

### TODO When To Use Cache

TODO

### TODO When To _NOT_ Use Cache

- Casting the cached data adds overhead
  - TODO add snippet & output of the different in using `static final List<Profile> CACHED_PROFILES` vs calling `(List<Profile>) CacheManager.transactionCache.get('cachedProfiles);` multiple times in 1 transaction (using a loop of 500)

## Platform Cache: A Quick Crash Course

- Types of cache partitions (org & session)
- Cache namespace
- Error handling for:
  - Specified partition name doesn't exist
  - Specified partion doesn't have any available storage space

## 1. Start Small: Implementing A Simple Transaction Cache

Now that we've discussed how constants & static variables work in Apex, let's start there. We need a fancy caching system in Apex - it should

- Provide Apex developers with the ability to add, retrieve, update, and clear cached data
- Support caching of any Apex data type
- Leverage a "key" name (`String`) as a way to add & retrieve cached data
  - Inherently, the key must also be unique, so the cache system should enforce uniqueness

We can implement all of these features, using only 3 lines of code.

```java
public without sharing class CacheManager_v1_super_simple {
    public static final Map<String, Object> TRANSACTION_CACHE = new Map<String, Object>();
}
```

Now, any Apex code can cache data that will be cached for the duration of an Apex transaction. This could be used for queried data, such as:

```java
public class MyClass {
    public static List<Profile> getProfiles() {
        return [SELECT Id, Name FROM Profile ORDER BY Name];
    }
}
```

### Considerations / Things To Be Aware Of

- Heap size is consumed
- Naming of keys could lead to separate, unrelated classes accidentally overwriting each other's cached data by unintentionally reusing the same key

## 2. Abstracting The Transaction Cache Implementation

The 3-line version of `CacheManager` is effective, but the implementation & the underlying data structure (`Map<String, Object>`) are currently the same thing - there's no abstraction at the moment, which can make it difficult to added additional safeguards & functionality into the caching system. Let's take the `CacheManager` class a step further, and we'll added a new inner class & methods to abstract away some of the inner-workings.

A bit of a prefactor here, but knowing that I want to support multiple types of caches, let's started by making the currently transaction cache be an inner class - this will make it easier in the next section to add support for new cache types.

```java
public without sharing class CacheManager_v2_transaction_class {
  private static TransactionCache transactionCache;

  public static TransactionCache getTransactionCache() {
    if (transactionCache == null) {
      transactionCache = new TransactionCache();
    }

    return transactionCache;
  }

  public class TransactionCache {
    private final Map<String, Object> keyToValue = new Map<String, Object>();

    private TransactionCache() {
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
  }
}
```

Internally, the transaction cache is still using the same `Map<String, Object>` data structure for caching, but that implementation detail is now hidden from consumers of `CacheManager`. An singleton instance of the new `TransactionCache` class now provides methods that interact with the `private Map<String, Object>` variable, which will later also provide the ability to further control how data is added, updated & removed in the cache.

## 3. Caching Data Across Transactions, Using Platform Cache

TODO - Discuss platform cache overview

The `CacheManager` class now provides a robust set of methods for managing the transaction cache, and the underlying data structure has been safely tucked away from consumers of `CacheManager`. Developers can add, update, retrieve & remove cached data as needed via Apex or the `CacheValue__mdt` custom metadata type. But fundamentally, the transaction cache has a flaw - the cached data only lasts for the life of the transaction. That means that every Apex transaction still has overhead of querying/generating data & adding it to the cache.

How can we further reduce some of this overhead? How can we cache data across multiple Apex transactions? One option is to use [Platform Cache](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_cache_namespace_overview.htm). This is another feature that Salesforce provides that supports caching data at two levels:

1. **Organization cache**: data cached in the org partition is available in Apex for any user, which provides a great place to cache data that _is not_ user-specific.
2. **Session cache**: data cached in the org partition is available in Apex a specific session for a specific user, which provides a great place to cache data that _is_ user-specific.

<!-- TODO add details about how much platform cache allocation is included in orgs by default  -->
<!-- It's important to note that orgs have XX platform cache space included  -->

TODO walk through creating a platform cache partition (with screenshots)

Let's incorporate Platform Cache into the `CacheManager` class - this will provide 3 types of cache (or 4, if you count `CacheValue__mdt` as an additional type of cache)

1. Transaction cache: the original cache we started with, using `Map<String, Object>`
2. Organization cache: our platform cache partition's org cache
3. Session cache: our platform cache partition's session cache

Ideally, Apex developers should be able to use all 3 cache types in the same way - developers will want to choose which cache type makes the most sense for each dataset being cached, but _using_ each cache should be consistent. This is a great time to introduce a new `interface` that all 3 cache types implement. The `TransactionCache` class already has several methods, so let's make a new `interface` with those methods.

```java
public without sharing class CacheManager_v3_cacheable_interface {
  @TestVisible
  private static final List<CacheValue__mdt> DECLARATIVE_CACHE_VALUES = CacheValue__mdt.getAll().values();

  private static Cacheable transactionCache;

  public interface Cacheable {
    Boolean contains(String key);
    Object get(String key);
    void put(String key, Object value);
    void remove(String key);
  }

  // The getTransactionCache() method now returns an instance of Cacheable, instead of TransactionCache
  // This provides yet another layer of abstraction for consumers of CacheManager, and ensures that how
  // consumers interact with each cache type is consistent (by adhering to the Cacheable interface's methods)
  public static Cacheable getTransactionCache() {
    if (transactionCache == null) {
      transactionCache = new TransactionCache();
    }

    return transactionCache;
  }

  // The TransactionCache class can now be marked as private - consumers of CacheManager will only need to know about the Cacheable interface
  private class TransactionCache implements Cacheable {
    private final Map<String, Object> keyToValue = new Map<String, Object>();

    private TransactionCache() {
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
  }
}
```

### Interacting With Platform Cache In Apex

Now, let's explore how to interact with Platform Cache in Apex. Most of this happens within the cleverly-named [`Cache` namespace](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_namespace_cache.htm).

TODO anonymous apex scripts for interacting with platform cache

### Integrating Platform Cache Into CacheManager

Using some of this information, let's update `CacheManager` to use Platform Cache.

```java
public class CacheManager_v4_with_platform_cache {
  private static final String PLATFORM_CACHE_NULL_VALUE = '<{(CACHE_VALUE_IS_NULL)}>'; // Presumably, no one will ever use this as an actual value

  // Private singleton instances of org, session, and transaction caches
  private static PlatformCache organizationCacheInstance;
  private static PlatformCache sessionCacheInstance;
  private static TransactionCache transactionCache;

  public interface Cacheable {
    Boolean contains(String key);
    Object get(String key);
    void put(String key, Object value);
    void remove(String key);
  }

  public static Cacheable getOrganizationCache() {
    if (organizationCacheInstance == null) {
      // For now, the partition name is hardcoded 😭 But we'll revisit this soon!
      Cache.Partition organizationPartition = Cache.Org.getPartition('CacheManagerPartition');
      organizationCacheInstance = new PlatformCache(organizationPartition, getTransactionCache());
    }

    return organizationCacheInstance;
  }

  public static Cacheable getSessionCache() {
    if (sessionCacheInstance == null) {
      // For now, the partition name is hardcoded 😭 But we'll revisit this soon!
      Cache.Partition sessionPartition = Cache.Session.getPartition('CacheManagerPartition');
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
  }

  private class TransactionCache implements Cacheable {
    private final Map<String, Object> keyToValue = new Map<String, Object>();

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
  }
}
```

Now, the `CacheManager` provides 3 ways to cache data

1. `CacheManager.getOrganizationCache()` - leverages the org partition in Platform Cache for storing cached data, and internally supplements it with the transaction cache.
2. `CacheManager.getSessionCache()` - leverages the session partition in Platform Cache for storing cached data, and internally supplements it with the transaction cache.
3. `CacheManager.getTransactionCache()` - leverages `Map<String, Object>` for storing cached data, and internally supplements it with declaratively cached data stored in `CacheValue__mdt`

And because all 3 of these methods return an instance of the interface `CacheManager.Cacheable`, the way that developers interact with each cache type is the same - developers only need to decide where they want to cache data.

## 4. Supporting Orgs That Don't Have Platform Cache Available

TODO - For ISVs, discuss adding in `PlatformCachePartitionDelegate` (or `Proxy`) class & how it helps with testability

```java
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
    Pattern targetPattern = Pattern.compile('^[a-zA-Z0-9]+$');

    Matcher regexMatcher = targetPattern.matcher(key);
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
    private final TransactionCache transactionCache;

    private PlatformCache(TransactionCache transactionCache, PlatformCachePartitionProxy cachePartitionProxy, Integer cacheTtlSeconds) {
      this.transactionCache = transactionCache;
      this.cachePartitionProxy = cachePartitionProxy;
      this.cacheTtlSeconds = cacheTtlSeconds;
    }

    public Boolean contains(String key) {
      if (this.transactionCache.contains(key) == true || this.cachePartitionProxy.isAvailable() == false) {
        return this.transactionCache.contains(key);
      } else {
        return this.cachePartitionProxy.contains(key);
      }
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

    public Boolean isAvailable() {
      return this.cachePartitionProxy.isAvailable() == true;
    }

    public void put(String key, Object value) {
      validateKey(key);
      this.transactionCache.put(key, value);

      // Platform cache does not support storing null values, so a predefined value is used as a substitute
      if (value == null) {
        value = PLATFORM_CACHE_NULL_VALUE;
      }
      Cache.Visibility visibility = Cache.Visibility.ALL;
      Boolean isImmutable = false;
      this.cachePartitionProxy.put(key, value, this.cacheTtlSeconds, visibility, isImmutable);
    }

    public void remove(String key) {
      this.transactionCache.remove(key);
      if (this.isAvailable() == true) {
        this.cachePartitionProxy.remove(key);
      }
    }
  }

  @TestVisible
  private virtual class PlatformCachePartitionProxy {
    private final Cache.Partition platformCachePartition;

    protected PlatformCachePartitionProxy(PlatformCacheType cacheType, String partitionName) {
      // Since orgs can customize the platform cache partition (via CacheConfiguration__mdt.PlatformCachePartitionName__c),
      // some orgs could have problematic configurations (or may have even deleted the referenced partition),
      // and it seems better to eat the exceptions & fallback to the transaction cache (which doesn't rely on Platform Cache).
      // The alternative is a runtime exception, which isn't ideal.
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

    private TransactionCache() {
    }

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
```

## 5. Scope-Creep Part 1: Declaratively Controlling Cache Runtime Behavior, Using `CacheConfiguration__mdt` Custom Metadata Type

TODO - discuss `CacheConfiguration__mdt`

```java
public without sharing class CacheManager_v6_configurations {
  @TestVisible
  private static final Map<String, Cacheable> CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE = new Map<String, Cacheable>();

  @TestVisible
  private static final List<CacheValue__mdt> DECLARATIVE_CACHE_VALUES = Schema.CacheValue__mdt.getAll().values();
  @TestVisible
  private static final String PLATFORM_CACHE_NULL_VALUE = '<{(CACHE_VALUE_IS_NULL)}>'; // Presumably, no one will ever use this as an actual value
  private static final CacheConfiguration__mdt ORGANIZATION_CACHE_CONFIGURATION = Schema.CacheConfiguration__mdt.getInstance('Organization');
  private static final CacheConfiguration__mdt SESSION_CACHE_CONFIGURATION = Schema.CacheConfiguration__mdt.getInstance('Session');
  private static final CacheConfiguration__mdt TRANSACTION_CACHE_CONFIGURATION = Schema.CacheConfiguration__mdt.getInstance('Transaction');

  private enum PlatformCacheType {
    ORGANIZATION,
    SESSION
  }

  public interface Cacheable {
    Boolean contains(String key);
    Object get(String key);
    Boolean isAvailable();
    Boolean isEnabled();
    Boolean isImmutable();
    void put(String key, Object value);
    void remove(String key);
  }

  public static Cacheable getOrganizationCache() {
    return getOrganizationCache(ORGANIZATION_CACHE_CONFIGURATION);
  }

  public static Cacheable getOrganizationCache(CacheConfiguration__mdt configuration) {
    return getPlatformCache(configuration, PlatformCacheType.ORGANIZATION);
  }

  public static Cacheable getSessionCache() {
    return getSessionCache(SESSION_CACHE_CONFIGURATION);
  }

  public static Cacheable getSessionCache(CacheConfiguration__mdt configuration) {
    return getPlatformCache(configuration, PlatformCacheType.SESSION);
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

  private static Cacheable getPlatformCache(CacheConfiguration__mdt configuration, PlatformCacheType cacheType) {
    if (CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.containsKey(configuration.DeveloperName)) {
      return CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.get(configuration.DeveloperName);
    }

    PlatformCachePartitionProxy partitionProxy = new PlatformCachePartitionProxy(cacheType, configuration.PlatformCachePartitionName__c);
    CacheConfiguration__mdt localTransactionCacheConfiguration = new CacheConfiguration__mdt(
      IsEnabled__c = true,
      IsImmutable__c = configuration.IsImmutable__c
    );

    PlatformCache platformCache = new PlatformCache(configuration, new TransactionCache(localTransactionCacheConfiguration), partitionProxy);
    CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.put(configuration.DeveloperName, platformCache);

    return platformCache;
  }

  private class PlatformCache implements Cacheable {
    private final PlatformCachePartitionProxy cachePartitionProxy;
    private final CacheConfiguration__mdt configuration;
    private final TransactionCache transactionCache;

    private PlatformCache(CacheConfiguration__mdt configuration, transactionCache transactionCache, PlatformCachePartitionProxy cachePartitionProxy) {
      this.configuration = configuration;
      this.transactionCache = transactionCache;
      this.cachePartitionProxy = cachePartitionProxy;
    }

    public Boolean contains(String key) {
      if (this.configuration.IsEnabled__c == false || this.transactionCache.contains(key) || this.cachePartitionProxy.isAvailable() == false) {
        return this.transactionCache.contains(key);
      } else {
        return this.cachePartitionProxy.contains(key);
      }
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

    public Boolean isAvailable() {
      return this.isEnabled() && this.cachePartitionProxy.isAvailable() == true;
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

      if (this.isAvailable() == true && this.isImmutable() == false || this.contains(key) == false) {
        // Platform cache does not support storing null values, so a predefined value is used as a substitute
        if (value == null) {
          value = PLATFORM_CACHE_NULL_VALUE;
        }
        Cache.Visibility visibility = Cache.Visibility.valueOf(this.configuration.PlatformCacheVisibility__c.toUpperCase());
        this.cachePartitionProxy.put(key, value, this.configuration.PlatformCacheTimeToLive__c.intValue(), visibility, this.configuration.IsImmutable__c);
      }
    }

    public void remove(String key) {
      if (this.isImmutable() == true) {
        return;
      }

      this.transactionCache.remove(key);
      if (this.isAvailable() == true) {
        this.cachePartitionProxy.remove(key);
      }
    }

    public void remove(Set<String> keys) {
      for (String key : keys) {
        this.remove(key);
      }
    }
  }

  @TestVisible
  private virtual class PlatformCachePartitionProxy {
    private final Cache.Partition platformCachePartition;

    protected PlatformCachePartitionProxy(PlatformCacheType cacheType, String partitionName) {
      // Since orgs can customize the platform cache partition (via CacheConfiguration__mdt.PlatformCachePartitionName__c),
      // some orgs could have problematic configurations (or may have even deleted the referenced partition),
      // and it seems better to eat the exceptions & fallback to the transaction cache (which doesn't rely on Platform Cache).
      // The alternative is a runtime exception, which isn't ideal.
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

    private TransactionCache(CacheConfiguration__mdt configuration) {
      this.configuration = configuration;
    }

    public Boolean contains(String key) {
      return this.keyToValue.containsKey(key);
    }

    public Object get(String key) {
      return this.keyToValue.get(key);
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

    public void remove(String key) {
      if (this.isEnabled() == true && this.isImmutable() == false) {
        this.keyToValue.remove(key);
      }
    }
  }
}
```

## 6. Scope-Creep Part 2: Declaratively Populating Cache Data Across Transactions, Using `CacheValue__mdt` Custom Metadata Type

We now have a strong foundation for caching data - but it has several limitations:

1. By the nature of it being a transaction cache, the cached data has to be initialized at the start of each Apex transaction, and at the end of the transaction, any cached data is discarded.
2. Developers have to write code to populate/update the cached value.

There can certainly be situations where transaction cache is the right place to cache data - some data will not change during the context of a single transaction, but may change inbetween different transactions. But is there still a way to improve how data is populated into the transaction cache? If an urgent issue comes up & something with the cached data is incorrect, do developers need to immediately deploy a hotfix to correct? What if some cached data doesn't change frequently, but admins & developers want a way to manually change it?

We can add a new custom metadata type as another mechanism for storing cached data. Let's start with building a new custom metadata type that we'll call `CacheValue__mdt`

TODO add screenshots

Now that we have a declarative place to store cached data, let's incorporate it into the `CacheManager` class.

```java
public without sharing class CacheManager_v7_declarative_cache {
  @TestVisible
  private static final Map<String, Cacheable> CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE = new Map<String, Cacheable>();

  @TestVisible
  private static final List<CacheValue__mdt> DECLARATIVE_CACHE_VALUES = Schema.CacheValue__mdt.getAll().values();
  @TestVisible
  private static final String PLATFORM_CACHE_NULL_VALUE = '<{(CACHE_VALUE_IS_NULL)}>'; // Presumably, no one will ever use this as an actual value
  private static final CacheConfiguration__mdt ORGANIZATION_CACHE_CONFIGURATION = Schema.CacheConfiguration__mdt.getInstance('Organization');
  private static final CacheConfiguration__mdt SESSION_CACHE_CONFIGURATION = Schema.CacheConfiguration__mdt.getInstance('Session');
  private static final CacheConfiguration__mdt TRANSACTION_CACHE_CONFIGURATION = Schema.CacheConfiguration__mdt.getInstance('Transaction');

  private enum PlatformCacheType {
    ORGANIZATION,
    SESSION
  }

  public interface Cacheable {
    Boolean contains(String key);
    Object get(String key);
    Boolean isAvailable();
    Boolean isEnabled();
    Boolean isImmutable();
    void put(String key, Object value);
    void put(Map<String, Object> keyToValue);
    void remove(String key);
  }

  public static Cacheable getOrganizationCache() {
    return getOrganizationCache(ORGANIZATION_CACHE_CONFIGURATION);
  }

  public static Cacheable getOrganizationCache(CacheConfiguration__mdt configuration) {
    return getPlatformCache(configuration, PlatformCacheType.ORGANIZATION);
  }

  public static Cacheable getSessionCache() {
    return getSessionCache(SESSION_CACHE_CONFIGURATION);
  }

  public static Cacheable getSessionCache(CacheConfiguration__mdt configuration) {
    return getPlatformCache(configuration, PlatformCacheType.SESSION);
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

  private static Cacheable getPlatformCache(CacheConfiguration__mdt configuration, PlatformCacheType cacheType) {
    if (CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.containsKey(configuration.DeveloperName)) {
      return CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.get(configuration.DeveloperName);
    }

    PlatformCachePartitionProxy partitionProxy = new PlatformCachePartitionProxy(cacheType, configuration.PlatformCachePartitionName__c);
    CacheConfiguration__mdt localTransactionCacheConfiguration = new CacheConfiguration__mdt(
      IsEnabled__c = true,
      IsImmutable__c = configuration.IsImmutable__c
    );

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
        Boolean isString = declarativeCacheValue.DataType__c == String.class.getName();
        Object castedValue = isString ? declarativeCacheValue.Value__c : JSON.deserialize(declarativeCacheValue.Value__c, dataType);
        keyToCacheValue.put(declarativeCacheValue.Key__c, castedValue);
      }
    }
    return keyToCacheValue;
  }

  private class PlatformCache implements Cacheable {
    private final PlatformCachePartitionProxy cachePartitionProxy;
    private final CacheConfiguration__mdt configuration;
    private final TransactionCache transactionCache;

    private PlatformCache(CacheConfiguration__mdt configuration, transactionCache transactionCache, PlatformCachePartitionProxy cachePartitionProxy) {
      this.configuration = configuration;
      this.transactionCache = transactionCache;
      this.cachePartitionProxy = cachePartitionProxy;

      this.put(loadDeclarativeCacheValues(this.configuration));
    }

    public Boolean contains(String key) {
      if (this.configuration.IsEnabled__c == false || this.transactionCache.contains(key) || this.cachePartitionProxy.isAvailable() == false) {
        return this.transactionCache.contains(key);
      } else {
        return this.cachePartitionProxy.contains(key);
      }
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

    public Boolean isAvailable() {
      return this.isEnabled() && this.cachePartitionProxy.isAvailable() == true;
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

      if (this.isAvailable() == true && this.isImmutable() == false || this.contains(key) == false) {
        // Platform cache does not support storing null values, so a predefined value is used as a substitute
        if (value == null) {
          value = PLATFORM_CACHE_NULL_VALUE;
        }
        Cache.Visibility visibility = Cache.Visibility.valueOf(this.configuration.PlatformCacheVisibility__c.toUpperCase());
        this.cachePartitionProxy.put(key, value, this.configuration.PlatformCacheTimeToLive__c.intValue(), visibility, this.configuration.IsImmutable__c);
      }
    }

    public void put(Map<String, Object> keyToValue) {
      for (String key : keyToValue.keySet()) {
        this.put(key, keyToValue.get(key));
      }
    }

    public void remove(String key) {
      if (this.isImmutable() == true) {
        return;
      }

      this.transactionCache.remove(key);
      if (this.isAvailable() == true) {
        this.cachePartitionProxy.remove(key);
      }
    }
  }

  @TestVisible
  private virtual class PlatformCachePartitionProxy {
    private final Cache.Partition platformCachePartition;

    protected PlatformCachePartitionProxy(PlatformCacheType cacheType, String partitionName) {
      // Since orgs can customize the platform cache partition (via CacheConfiguration__mdt.PlatformCachePartitionName__c),
      // some orgs could have problematic configurations (or may have even deleted the referenced partition),
      // and it seems better to eat the exceptions & fallback to the transaction cache (which doesn't rely on Platform Cache).
      // The alternative is a runtime exception, which isn't ideal.
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

    private TransactionCache(CacheConfiguration__mdt configuration) {
      this.configuration = configuration;

      this.put(loadDeclarativeCacheValues(this.configuration));
    }

    public Boolean contains(String key) {
      return this.keyToValue.containsKey(key);
    }

    public Object get(String key) {
      return this.keyToValue.get(key);
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

    public void put(Map<String, Object> keyToValue) {
      for (String key : keyToValue.keySet()) {
        this.put(key, keyToValue.get(key));
      }
    }

    public void remove(String key) {
      if (this.isEnabled() == true && this.isImmutable() == false) {
        this.keyToValue.remove(key);
      }
    }
  }
}
```

## 7. Scope-Creep Part 3: Adding Some Handy Methods

TODO discuss adding new methods to `Cacheable` interface to provide Apex developers more control of the caching system

1. `Map<String, Boolean> contains(Set<String> keys);`
2. `Boolean containsAll(Set<String> keys);`
3. `Map<String, Object> get(Set<String> keys);`
4. `Map<String, Object> getAll();`
5. `Set<String> getKeys();`
6. `void put(Map<String, Object> keyToValue)`
7. `void remove(Set<String> keys)`
8. `void removeAll()`

```java
public without sharing class CacheManager_v8_final_touches {
  @TestVisible
  private static final Map<String, Cacheable> CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE = new Map<String, Cacheable>();

  @TestVisible
  private static final List<CacheValue__mdt> DECLARATIVE_CACHE_VALUES = Schema.CacheValue__mdt.getAll().values();
  @TestVisible
  private static final String PLATFORM_CACHE_NULL_VALUE = '<{(CACHE_VALUE_IS_NULL)}>'; // Presumably, no one will ever use this as an actual value
  private static final CacheConfiguration__mdt ORGANIZATION_CACHE_CONFIGURATION = Schema.CacheConfiguration__mdt.getInstance('Organization');
  private static final CacheConfiguration__mdt SESSION_CACHE_CONFIGURATION = Schema.CacheConfiguration__mdt.getInstance('Session');
  private static final CacheConfiguration__mdt TRANSACTION_CACHE_CONFIGURATION = Schema.CacheConfiguration__mdt.getInstance('Transaction');

  private enum PlatformCacheType {
    ORGANIZATION,
    SESSION
  }

  public interface Cacheable {
    Boolean contains(String key);
    Map<String, Boolean> contains(Set<String> keys);
    Boolean containsAll(Set<String> keys);
    Object get(String key);
    Map<String, Object> get(Set<String> keys);
    Map<String, Object> getAll();
    Set<String> getKeys();
    Boolean isAvailable();
    Boolean isEnabled();
    Boolean isImmutable();
    void put(String key, Object value);
    void put(Map<String, Object> keyToValue);
    void remove(String key);
    void remove(Set<String> keys);
    void removeAll();
  }

  public static Cacheable getOrganizationCache() {
    return getOrganizationCache(ORGANIZATION_CACHE_CONFIGURATION);
  }

  public static Cacheable getOrganizationCache(CacheConfiguration__mdt configuration) {
    return getPlatformCache(configuration, PlatformCacheType.ORGANIZATION);
  }

  public static Cacheable getSessionCache() {
    return getSessionCache(SESSION_CACHE_CONFIGURATION);
  }

  public static Cacheable getSessionCache(CacheConfiguration__mdt configuration) {
    return getPlatformCache(configuration, PlatformCacheType.SESSION);
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

  private static Cacheable getPlatformCache(CacheConfiguration__mdt configuration, PlatformCacheType cacheType) {
    if (CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.containsKey(configuration.DeveloperName)) {
      return CONFIGURATION_DEVELOPER_NAME_TO_CACHEABLE_INSTANCE.get(configuration.DeveloperName);
    }

    PlatformCachePartitionProxy partitionProxy = new PlatformCachePartitionProxy(cacheType, configuration.PlatformCachePartitionName__c);
    CacheConfiguration__mdt localTransactionCacheConfiguration = new CacheConfiguration__mdt(
      IsEnabled__c = true,
      IsImmutable__c = configuration.IsImmutable__c
    );

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
        Boolean isString = declarativeCacheValue.DataType__c == String.class.getName();
        Object castedValue = isString ? declarativeCacheValue.Value__c : JSON.deserialize(declarativeCacheValue.Value__c, dataType);
        keyToCacheValue.put(declarativeCacheValue.Key__c, castedValue);
      }
    }
    return keyToCacheValue;
  }

  private class PlatformCache implements Cacheable {
    private final PlatformCachePartitionProxy cachePartitionProxy;
    private final CacheConfiguration__mdt configuration;
    private final TransactionCache transactionCache;

    private PlatformCache(CacheConfiguration__mdt configuration, transactionCache transactionCache, PlatformCachePartitionProxy cachePartitionProxy) {
      this.configuration = configuration;
      this.transactionCache = transactionCache;
      this.cachePartitionProxy = cachePartitionProxy;

      this.put(loadDeclarativeCacheValues(this.configuration));
    }

    public Boolean contains(String key) {
      if (this.configuration.IsEnabled__c == false || this.transactionCache.contains(key) || this.cachePartitionProxy.isAvailable() == false) {
        return this.transactionCache.contains(key);
      } else {
        return this.cachePartitionProxy.contains(key);
      }
    }

    public Map<String, Boolean> contains(Set<String> keys) {
      return this.cachePartitionProxy.contains(keys);
    }

    public Boolean containsAll(Set<String> keys) {
      Map<String, Boolean> keyToContainsResult = this.cachePartitionProxy.contains(keys);
      if (keyToContainsResult == null || keyToContainsResult.isEmpty() == true) {
        return false;
      }

      for (String key : keyToContainsResult.keySet()) {
        Boolean containsKey = keyToContainsResult.get(key);
        if (containsKey == false) {
          return false;
        }
      }
      return true;
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

    public Set<String> getKeys() {
      return this.isAvailable() == true ? this.cachePartitionProxy.getKeys() : this.transactionCache.getKeys();
    }

    public Boolean isAvailable() {
      return this.isEnabled() && this.cachePartitionProxy.isAvailable() == true;
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

      if (this.isAvailable() == true && this.isImmutable() == false || this.contains(key) == false) {
        // Platform cache does not support storing null values, so a predefined value is used as a substitute
        if (value == null) {
          value = PLATFORM_CACHE_NULL_VALUE;
        }
        Cache.Visibility visibility = Cache.Visibility.valueOf(this.configuration.PlatformCacheVisibility__c.toUpperCase());
        this.cachePartitionProxy.put(key, value, this.configuration.PlatformCacheTimeToLive__c.intValue(), visibility, this.configuration.IsImmutable__c);
      }
    }

    public void put(Map<String, Object> keyToValue) {
      for (String key : keyToValue.keySet()) {
        this.put(key, keyToValue.get(key));
      }
    }

    public void remove(String key) {
      if (this.isImmutable() == true) {
        return;
      }

      this.transactionCache.remove(key);
      if (this.isAvailable() == true) {
        this.cachePartitionProxy.remove(key);
      }
    }

    public void remove(Set<String> keys) {
      for (String key : keys) {
        this.remove(key);
      }
    }

    public void removeAll() {
      for (String key : this.getKeys()) {
        this.remove(key);
      }
    }
  }

  @TestVisible
  private virtual class PlatformCachePartitionProxy {
    private final Cache.Partition platformCachePartition;

    protected PlatformCachePartitionProxy(PlatformCacheType cacheType, String partitionName) {
      // Since orgs can customize the platform cache partition (via CacheConfiguration__mdt.PlatformCachePartitionName__c),
      // some orgs could have problematic configurations (or may have even deleted the referenced partition),
      // and it seems better to eat the exceptions & fallback to the transaction cache (which doesn't rely on Platform Cache).
      // The alternative is a runtime exception, which isn't ideal.
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

    public Map<String, Boolean> contains(Set<String> keys) {
      Map<String, Boolean> keyToContainsResult = this.platformCachePartition?.contains(keys);
      if (keyToContainsResult == null) {
        keyToContainsResult = new Map<String, Boolean>();
      }
      if (keyToContainsResult.isEmpty() == true) {
        for (String key : keys) {
          keyToContainsResult.put(key, false);
        }
      }
      return keyToContainsResult;
    }

    public Boolean containsAll(Set<String> keys) {
      Map<String, Boolean> keyToContainsResult = this.platformCachePartition?.contains(keys);
      if (keyToContainsResult == null || keyToContainsResult.isEmpty() == true) {
        return false;
      }

      for (String key : keyToContainsResult.keySet()) {
        Boolean containsKey = keyToContainsResult.get(key);
        if (containsKey == false) {
          return false;
        }
      }
      return true;
    }

    public virtual Object get(String key) {
      return this.platformCachePartition?.get(key);
    }

    public virtual Map<String, Object> get(Set<String> keys) {
      return this.isAvailable() == false ? new Map<String, Object>() : this.platformCachePartition.get(keys);
    }

    public virtual Set<String> getKeys() {
      return this.isAvailable() == false ? new Set<String>() : this.platformCachePartition.getKeys();
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

    private TransactionCache(CacheConfiguration__mdt configuration) {
      this.configuration = configuration;

      this.put(loadDeclarativeCacheValues(this.configuration));
    }

    public Boolean contains(String key) {
      return this.keyToValue.containsKey(key);
    }

    public Map<String, Boolean> contains(Set<String> keys) {
      Map<String, Boolean> keyToContainsResult = new Map<String, Boolean>();
      for (String key : keys) {
        keyToContainsResult.put(key, this.contains(key));
      }
      return keyToContainsResult;
    }

    public Boolean containsAll(Set<String> keys) {
      return this.keyToValue.keySet().containsAll(keys);
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

    public Set<String> getKeys() {
      return this.keyToValue.keySet();
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

    public void put(Map<String, Object> keyToValue) {
      for (String key : keyToValue.keySet()) {
        this.put(key, keyToValue.get(key));
      }
    }

    public void remove(String key) {
      if (this.isEnabled() == true && this.isImmutable() == false) {
        this.keyToValue.remove(key);
      }
    }

    public void remove(Set<String> keys) {
      for (String key : keys) {
        this.remove(key);
      }
    }

    public void removeAll() {
      if (this.isEnabled() == true && this.isImmutable() == false) {
        this.keyToValue.clear();
      }
    }
  }
}

```

## Wrapping Up

TODO add example usage of all the cache types
