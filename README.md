# Nebula Cache Manager

[![Build](https://github.com/jongpie/NebulaCacheManager/actions/workflows/build.yml/badge.svg)](https://github.com/jongpie/NebulaCacheManager/actions/workflows/build.yml)
[![codecov](https://codecov.io/gh/jongpie/NebulaCacheManager/branch/main/graph/badge.svg?token=1DJPDRM3N4)](https://codecov.io/gh/jongpie/NebulaCacheManager)
[![Documentation Status](https://readthedocs.org/projects/nebulacachemanager/badge/?version=latest)](https://nebulacachemanager.readthedocs.io/en/latest/?badge=latest)

A flexible cache management system for Salesforce Apex developers. Built to be scalable & configurable.

Learn more about the history & implementation of this repo in [the Joys of Apex article 'Iteratively Building a Flexible Caching System for Apex'](https://www.jamessimone.net/blog/joys-of-apex/iteratively-building-a-flexible-caching-system/)

## Unlocked Package - `Nebula` Namespace - v1.0.3

[![Install Unlocked Package (Nebula namespace) in a Sandbox](./images/btn-install-unlocked-package-sandbox.png)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04t5Y0000015nCfQAI)
[![Install Unlocked Package (Nebula namespace) in Production](./images/btn-install-unlocked-package-production.png)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04t5Y0000015nCfQAI)

## Unlocked Package - No Namespace - v1.0.3

[![Install Unlocked Package (no namespace) in a Sandbox](./images/btn-install-unlocked-package-sandbox.png)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04t5Y0000015nCaQAI)
[![Install Unlocked Package (no namespace) in Production](./images/btn-install-unlocked-package-production.png)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04t5Y0000015nCaQAI)

---

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
