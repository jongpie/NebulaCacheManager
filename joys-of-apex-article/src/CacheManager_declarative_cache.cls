public without sharing class CacheManager_declarative_cache {
  @TestVisible
  private static final List<CacheValue__mdt> DECLARATIVE_CACHE_VALUES = CacheValue__mdt.getAll().values();

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
      this.loadDeclarativeCacheValues();
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
      this.keyToValue.put(key, value);
    }

    public void remove(String key) {
      this.keyToValue.remove(key);
    }

    public void removeAll() {
      this.keyToValue.clear();
    }

    private void loadDeclarativeCacheValues() {
      for (CacheValue__mdt declarativeCacheValue : DECLARATIVE_CACHE_VALUES) {
        this.keyToValue.put(declarativeCacheValue.DeveloperName, declarativeCacheValue.Value__c);
      }
    }
  }
}
