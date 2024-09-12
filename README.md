# Nebula Cache Manager

A flexible cache management system for Salesforce Apex developers. Built to be scalable & configurable.

Learn more about the history & implementation of this repo in [the Joys of Apex article 'Iteratively Building a Flexible Caching System for Apex'](https://www.jamessimone.net/blog/joys-of-apex/iteratively-building-a-flexible-caching-system/)

## Unlocked Package - `Nebula` Namespace - v1.0.3

[![Install Unlocked Package (Nebula namespace) in a Sandbox](./images/btn-install-unlocked-package-sandbox.png)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04t5Y0000015nCfQAI)
[![Install Unlocked Package (Nebula namespace) in Production](./images/btn-install-unlocked-package-production.png)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04t5Y0000015nCfQAI)

## Unlocked Package - No Namespace - v1.0.3

[![Install Unlocked Package (no namespace) in a Sandbox](./images/btn-install-unlocked-package-sandbox.png)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04t5Y0000015nCaQAI)
[![Install Unlocked Package (no namespace) in Production](./images/btn-install-unlocked-package-production.png)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04t5Y0000015nCaQAI)

---
## Required setup after installation
Go to Setup -> Custom Code -> Platform Cache. Click on `CacheManagerPartition` then click Edit button set at least 1 MB for "Session Cache Allocation" and 1 MB "Org Cache Allocation".
This is needed as otherwise cache won't work with default 0 values.

If you want to debug and see what is stored in cache go to your user profile and check "Cache Diagnostics" checkbox, then save.  
Now if you go again to Platform Cache and click `CacheManagerPartition` you will see additional field with link arrow named "Diagnostics". When clicked it opens teh page with all details and statistics about cache.

## Optional setup
In Custom metadata you will see `Cache Configuration` and `Cache Value` metadata types.  
In `Cache Configuration` you can adjust if cache type is enabled or disabled, set it as immutable, set cache time to live value and define if it is global or namespace scoped cache.  
In `Cache Value` you can define persistent values which should be always available in cache.

## Cache Manager for Apex: Quick Start

For Apex developers, the `CacheManager` class has several methods that can be used to cache data in 1 of the 3 supported cache types - transaction, organization platform cache, and session platform cache. Each cache type implements the interface `CacheManager.Cacheable` - regardless of which cache type you choose, the way you interact with each cache type is consistent.

```java
// This will cache a Map<String, Group> that contains all queues in the current org (if the data has not been cached)
// or it will return the cached version of the data (if the data has previously been cached)
public static Map<String, Group> getQueues() {
    String cacheKey = 'queues';
    Map<String, Group> queueDeveloperNameToQueueGroup;
    if (CacheManager.getOrganization().contains(cacheKey)) {
        queueDeveloperNameToQueueGroup = (Map<String, Group>) CacheManager.getOrganization().get(cacheKey);
    } else {
        queueDeveloperNameToQueueGroup = new Map<String, Group>();
        for (Group queueGroup : [SELECT Id, DeveloperName, Email, Name FROM Group WHERE Type = 'Queue']) {
            queueDeveloperNameToQueueGroup.put(queueGroup.DeveloperName, queueGroup);
        }
        CacheManager.getOrganization().put(cacheKey, queueDeveloperNameToQueueGroup);
    }
    return queueDeveloperNameToQueueGroup;
}
```
