List<CacheManager.Cacheable> defaultCaches = new List<CacheManager.Cacheable>{
    CacheManager.getOrganizationCache(),
    CacheManager.getSessionCache(),
    CacheManager.getTransactionCache()
};

String key = 'someKey';
User value = [SELECT Id, Username, Email FROM User WHERE Id = :UserInfo.getUserId()];
for (CacheManager.Cacheable cache : defaultCaches) {
    System.Assert.isFalse(cache.contains(key));
    cache.put(key, value);
    System.Assert.isTrue(cache.contains(key));
    System.Assert.areEqual(value, cache.get(key));
    cache.remove(key);
    System.Assert.isFalse(cache.contains(key));
}