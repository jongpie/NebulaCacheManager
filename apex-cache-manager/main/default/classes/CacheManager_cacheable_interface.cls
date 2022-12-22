public without sharing class CacheManager_cacheable_interface {
  @TestVisible
  private static final List<CacheValue__mdt> DECLARATIVE_CACHE_VALUES = CacheValue__mdt.getAll().values();

  private static Cacheable transactionCache;

  public interface Cacheable {
    Set<String> getKeys();
    Boolean contains(String key);
    Object get(String key);
    void put(String key, Object value);
    void remove(String key);
    void removeAll();
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
