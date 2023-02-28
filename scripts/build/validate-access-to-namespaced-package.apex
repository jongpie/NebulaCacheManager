List<Nebula.CacheManager.Cacheable> defaultCaches = new List<Nebula.CacheManager.Cacheable>{
    Nebula.CacheManager.getOrganizationCache(),
    Nebula.CacheManager.getSessionCache(),
    Nebula.CacheManager.getTransactionCache()
};

String key = 'someKey';
User value = [SELECT Id, Username, Email FROM User WHERE Id = :UserInfo.getUserId()];
for (Nebula.CacheManager.Cacheable cache : caches) {
    System.Assert.isFalse(cache.contains(key));
    cache.put(key, value);
    System.Assert.isTrue(cache.contains(key));
    System.Assert.areEqual(value, cache.get(key));
    cache.remove(key);
    System.Assert.isFalse(cache.contains(key));
}