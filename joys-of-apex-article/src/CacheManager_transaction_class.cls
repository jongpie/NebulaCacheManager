public without sharing class CacheManager_transaction_class {
  // Singleton instance of the transaction cache
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
  }
}
