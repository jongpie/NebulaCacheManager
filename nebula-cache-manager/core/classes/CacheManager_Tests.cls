//---------------------------------------------------------------------------------------------------//
// This file is part of the Nebula Cache Manager project, released under the MIT License.            //
// See LICENSE file or go to https://github.com/jongpie/NebulaCacheManager for full license details. //
//---------------------------------------------------------------------------------------------------//

/**
 * @description When testing Platform Cache partitions, there is no way to directly mock the partitions. Furthermore, the partitions
 *              configured in the org are actually used in test contexts, so if a partition exists but does not have storage space
 *              allocated in the org, then any tests that try to assert that data is cached in the partitions will fail.
 *              To help overcome this platform limitation, a mock class - `MockPlatformCachePartitionProxy` - is used
 *              to simulate how the code would behave with different partition configurations.
 *              Additional integration tests (that actually test real platform cache partitions) are used in Nebula Logger's pipeline
 *              but are not included in core package since those tests may fail in some orgs.
 */
@SuppressWarnings('PMD.ApexDoc, PMD.ApexAssertionsShouldIncludeMessage, PMD.CyclomaticComplexity, PMD.MethodNamingConventions')
@IsTest(IsParallel=true)
private class CacheManager_Tests {
  static {
    CacheManager.CONFIGURED_CACHE_VALUES.clear();
  }

  @IsTest
  static void it_does_not_put_key_in_organisation_cache_when_configuration_is_disabled() {
    String mockKey = 'SomeKey';
    CacheConfiguration__mdt disabledConfiguration = new CacheConfiguration__mdt(
      IsEnabled__c = false,
      IsImmutable__c = true,
      PlatformCachePartitionName__c = 'Mock'
    );
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    CacheManager.Cacheable cache = CacheManager.getOrganizationCache(disabledConfiguration);
    System.Assert.isFalse(cache.contains(mockKey));

    cache.put(mockKey, mockValue);

    System.Assert.isFalse(cache.contains(mockKey));
  }

  @IsTest
  static void it_does_not_put_key_in_session_cache_when_configuration_is_disabled() {
    String mockKey = 'SomeKey';
    CacheConfiguration__mdt disabledConfiguration = new CacheConfiguration__mdt(
      IsEnabled__c = false,
      IsImmutable__c = true,
      PlatformCachePartitionName__c = 'Mock'
    );
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    CacheManager.Cacheable cache = CacheManager.getSessionCache(disabledConfiguration);
    System.Assert.isFalse(cache.contains(mockKey));

    cache.put(mockKey, mockValue);

    System.Assert.isFalse(cache.contains(mockKey));
  }

  @IsTest
  static void it_adds_new_key_to_transaction_cache() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    System.Assert.isFalse(CacheManager.getTransactionCache().contains(mockKey));

    CacheManager.getTransactionCache().put(mockKey, mockValue);

    System.Assert.isTrue(CacheManager.getTransactionCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getTransactionCache().get(mockKey));
  }

  @IsTest
  static void it_adds_new_key_with_null_value_to_transaction_cache() {
    String mockKey = 'SomeKey';
    User mockValue = null;
    System.Assert.isFalse(CacheManager.getTransactionCache().contains(mockKey));

    CacheManager.getTransactionCache().put(mockKey, mockValue);

    System.Assert.isTrue(CacheManager.getTransactionCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getTransactionCache().get(mockKey));
  }

  @IsTest
  static void it_adds_new_key_with_cachebuilder_to_transaction_cache_when_get_key() {
    String mockKey = 'SomeKey';
    System.Type cacheBuilderStubType = CacheBuilderStub.class;
    System.Assert.isFalse(CacheManager.getTransactionCache().contains(mockKey));

    Object generatedValue = CacheManager.getTransactionCache().get(mockKey, cacheBuilderStubType);

    System.Assert.isNotNull(generatedValue);
    System.Assert.isTrue(CacheManager.getTransactionCache().contains(mockKey));

    Object cachedValue = CacheManager.getTransactionCache().get(mockKey, cacheBuilderStubType);

    System.Assert.isNotNull(cachedValue);
    System.Assert.areEqual(generatedValue, cachedValue);
  }

  @IsTest
  static void it_adds_configured_key_and_value_to_transaction_cache() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    CacheValue__mdt configuredCacheValue = new CacheValue__mdt(
      Cache__c = CacheManager.TRANSACTION_CACHE_CONFIGURATION.Id,
      DataType__c = Schema.User.class.getName(),
      IsEnabled__c = true,
      Key__c = mockKey,
      Value__c = JSON.serialize(mockValue)
    );
    CacheManager.CONFIGURED_CACHE_VALUES.add(configuredCacheValue);

    System.Assert.isTrue(CacheManager.getTransactionCache().contains(mockKey));
    Object returnedValue = CacheManager.getTransactionCache().get(mockKey);

    System.Assert.areEqual(mockValue, returnedValue);
    System.Assert.isInstanceOfType(returnedValue, Schema.User.class);
    System.Assert.isTrue(CacheManager.getTransactionCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getTransactionCache().get(mockKey));
  }

  @IsTest
  static void it_updates_value_for_existing_key_in_transaction_cache() {
    String mockKey = 'SomeKey';
    User oldMockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    CacheManager.getTransactionCache().put(mockKey, oldMockValue);
    System.Assert.isTrue(CacheManager.getTransactionCache().contains(mockKey));
    System.Assert.areEqual(oldMockValue, CacheManager.getTransactionCache().get(mockKey));
    Account newMockValue = new Account(Name = 'Some fake account');

    CacheManager.getTransactionCache().put(mockKey, newMockValue);

    System.Assert.isTrue(CacheManager.getTransactionCache().contains(mockKey));
    System.Assert.areEqual(newMockValue, CacheManager.getTransactionCache().get(mockKey));
  }

  @IsTest
  static void it_removes_value_for_existing_key_in_transaction_cache() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    System.Assert.isFalse(CacheManager.getTransactionCache().contains(mockKey));
    CacheManager.getTransactionCache().put(mockKey, mockValue);
    System.Assert.isTrue(CacheManager.getTransactionCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getTransactionCache().get(mockKey));

    CacheManager.getTransactionCache().remove(mockKey);

    System.Assert.isFalse(CacheManager.getTransactionCache().contains(mockKey));
  }

  @IsTest
  static void it_supports_bulk_operations_in_transaction_cache() {
    System.Assert.isTrue(CacheManager.getTransactionCache().containsAll(new Set<String>()));
    System.Assert.isTrue(CacheManager.getTransactionCache().isAvailable());
    Map<String, Object> keyToValue = new Map<String, Object>{
      'SomeDate' => Date.newInstance(1999, 9, 9),
      'SomeString' => 'hello, world',
      'SomeSObject' => new User(Id = System.UserInfo.getUserId())
    };
    System.Assert.isFalse(CacheManager.getTransactionCache().containsAll(keyToValue.keySet()));
    CacheManager.getTransactionCache().put(keyToValue);
    for (String key : keyToValue.keySet()) {
      System.Assert.isTrue(CacheManager.getTransactionCache().contains(key));
    }
    Map<String, Boolean> keyToContainsResult = CacheManager.getTransactionCache().contains(keyToValue.keySet());
    for (String key : keyToContainsResult.keySet()) {
      Boolean containsResult = keyToContainsResult.get(key);
      System.Assert.isTrue(containsResult, 'Cache did not contain key: ' + key);
      System.Assert.isTrue(CacheManager.getTransactionCache().contains(key));
    }
    Map<String, Object> returnedKeyToValue = CacheManager.getTransactionCache().getAll();
    System.Assert.areEqual(keyToValue, returnedKeyToValue);
    System.Assert.isTrue(CacheManager.getTransactionCache().containsAll(keyToValue.keySet()), '' + CacheManager.getTransactionCache().getKeys());
    CacheManager.getTransactionCache().remove(keyToValue.keySet());
    System.Assert.isFalse(CacheManager.getTransactionCache().containsAll(keyToValue.keySet()));
  }

  @IsTest
  static void it_remove_alls_keys_in_transaction_cache_when_remove_all_method_is_called() {
    System.Assert.isTrue(CacheManager.getTransactionCache().isAvailable());
    Map<String, Object> keyToValue = new Map<String, Object>{
      'SomeDate' => Date.newInstance(1999, 9, 9),
      'SomeString' => 'hello, world',
      'SomeSObject' => new User(Id = System.UserInfo.getUserId())
    };
    CacheManager.getTransactionCache().put(keyToValue);
    System.Assert.areEqual(keyToValue.keySet(), CacheManager.getTransactionCache().getKeys());

    CacheManager.getTransactionCache().removeAll();

    System.Assert.isTrue(CacheManager.getTransactionCache().getKeys().isEmpty());
  }

  @IsTest
  static void it_adds_new_key_to_organization_cache_when_organization_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(1, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.putMethodCallCount);

    CacheManager.getOrganizationCache().put(mockKey, mockValue);

    System.Assert.areEqual(1, mockOrganizationPartitionProxy.putMethodCallCount);
    System.Assert.isTrue(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.areEqual(mockValue, mockOrganizationPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getOrganizationCache().get(mockKey));
  }

  @IsTest
  static void it_gets_value_from_organization_cache_when_transaction_cache_miss_and_organization_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(true);
    mockOrganizationPartitionProxy.put(mockKey, mockValue, 3600, Cache.Visibility.ALL, false);
    System.Assert.isTrue(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(1, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.getMethodCallCount);

    Object actualResult = CacheManager.getOrganizationCache().get(mockKey);

    System.Assert.areEqual(1, mockOrganizationPartitionProxy.getMethodCallCount);
    System.Assert.areEqual(mockValue, actualResult);
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
  }

  @IsTest
  static void it_gets_value_from_session_cache_when_transaction_cache_miss_and_session_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(true);
    mockSessionPartitionProxy.put(mockKey, mockValue, 3600, Cache.Visibility.ALL, false);
    System.Assert.isTrue(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.areEqual(0, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(1, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockSessionPartitionProxy.getMethodCallCount);

    Object actualResult = CacheManager.getSessionCache().get(mockKey);

    System.Assert.areEqual(1, mockSessionPartitionProxy.getMethodCallCount);
    System.Assert.areEqual(mockValue, actualResult);
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
  }

  @IsTest
  static void it_gets_null_from_organization_cache_when_transaction_cache_miss_and_organization_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(true);
    mockOrganizationPartitionProxy.put(mockKey, CacheManager.PLATFORM_CACHE_NULL_VALUE, 3600, Cache.Visibility.ALL, false);
    System.Assert.isTrue(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(1, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.getMethodCallCount);

    Object actualResult = CacheManager.getOrganizationCache().get(mockKey);

    System.Assert.areEqual(1, mockOrganizationPartitionProxy.getMethodCallCount);
    System.Assert.areEqual(null, actualResult);
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
  }

  @IsTest
  static void it_gets_null_from_session_cache_when_transaction_cache_miss_and_session_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(true);
    mockSessionPartitionProxy.put(mockKey, CacheManager.PLATFORM_CACHE_NULL_VALUE, 3600, Cache.Visibility.ALL, false);
    System.Assert.isTrue(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.areEqual(0, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(1, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockSessionPartitionProxy.getMethodCallCount);

    Object actualResult = CacheManager.getSessionCache().get(mockKey);

    System.Assert.areEqual(1, mockSessionPartitionProxy.getMethodCallCount);
    System.Assert.areEqual(null, actualResult);
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
  }

  @IsTest
  static void it_adds_new_key_to_fallback_transaction_cache_when_organization_platform_cache_is_not_available() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(false);
    System.Assert.isFalse(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.putMethodCallCount);

    CacheManager.getOrganizationCache().put(mockKey, mockValue);

    System.Assert.areEqual(0, mockOrganizationPartitionProxy.putMethodCallCount);
    System.Assert.isFalse(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.isNull(mockOrganizationPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getOrganizationCache().get(mockKey));
  }

  @IsTest
  static void it_adds_new_key_to_organization_cache_with_cachebuilder_when_organization_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    System.Type cacheBuilderStubType = CacheBuilderStub.class;
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(1, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.getCacheBuilderMethodCallCount);

    Object generatedValue = CacheManager.getOrganizationCache().get(mockKey, cacheBuilderStubType);

    System.Assert.areEqual(1, mockOrganizationPartitionProxy.getCacheBuilderMethodCallCount);
    System.Assert.isTrue(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.isNotNull(generatedValue);

    Object cachedValue = CacheManager.getOrganizationCache().get(mockKey, cacheBuilderStubType);

    System.Assert.isNotNull(cachedValue);
    System.Assert.areEqual(generatedValue, cachedValue);
    System.Assert.areEqual(1, mockOrganizationPartitionProxy.getCacheBuilderMethodCallCount);
    System.Assert.areEqual(cachedValue, mockOrganizationPartitionProxy.get(mockKey));
    System.Assert.isTrue(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(cachedValue, CacheManager.getOrganizationCache().get(mockKey));
  }

  @IsTest
  static void it_adds_new_key_to_fallback_transaction_cache_with_cachebuilder_when_organization_platform_cache_is_not_available() {
    String mockKey = 'SomeKey';
    System.Type cacheBuilderStubType = CacheBuilderStub.class;
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(false);
    System.Assert.isFalse(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.getCacheBuilderMethodCallCount);

    Object generatedValue = CacheManager.getOrganizationCache().get(mockKey, cacheBuilderStubType);

    System.Assert.areEqual(0, mockOrganizationPartitionProxy.getCacheBuilderMethodCallCount);
    System.Assert.isFalse(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.isNotNull(generatedValue);

    Object cachedValue = CacheManager.getOrganizationCache().get(mockKey, cacheBuilderStubType);

    System.Assert.isNotNull(cachedValue);
    System.Assert.areEqual(generatedValue, cachedValue);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.getCacheBuilderMethodCallCount);
    System.Assert.isNull(mockOrganizationPartitionProxy.get(mockKey));
    System.Assert.isFalse(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(cachedValue, CacheManager.getOrganizationCache().get(mockKey));
  }

  @IsTest
  static void it_adds_configured_key_and_value_to_organization_cache_when_organization_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    CacheValue__mdt configuredCacheValue = new CacheValue__mdt(
      Cache__c = CacheManager.ORGANIZATION_CACHE_CONFIGURATION.Id,
      DataType__c = Schema.User.class.getName(),
      IsEnabled__c = true,
      Key__c = mockKey,
      Value__c = JSON.serialize(mockValue)
    );
    CacheManager.CONFIGURED_CACHE_VALUES.add(configuredCacheValue);
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);

    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    Object returnedValue = CacheManager.getOrganizationCache().get(mockKey);

    System.Assert.areEqual(mockValue, returnedValue);
    System.Assert.isInstanceOfType(returnedValue, Schema.User.class);
    System.Assert.areEqual(mockValue, mockOrganizationPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getOrganizationCache().get(mockKey));
  }

  @IsTest
  static void it_adds_configured_key_with_null_value_to_organization_cache_when_organization_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    CacheValue__mdt configuredCacheValue = new CacheValue__mdt(
      Cache__c = CacheManager.ORGANIZATION_CACHE_CONFIGURATION.Id,
      DataType__c = String.class.getName(),
      IsEnabled__c = true,
      Key__c = mockKey,
      Value__c = null
    );
    CacheManager.CONFIGURED_CACHE_VALUES.add(configuredCacheValue);
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);

    Object returnedValue = CacheManager.getOrganizationCache().get(mockKey);

    System.Assert.areEqual(null, returnedValue);
    System.Assert.areEqual(CacheManager.PLATFORM_CACHE_NULL_VALUE, mockOrganizationPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(null, CacheManager.getOrganizationCache().get(mockKey));
  }

  @IsTest
  static void it_adds_new_key_with_null_value_to_organization_cache_when_organization_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    User mockValue = null;
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(1, mockOrganizationPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.putMethodCallCount);

    CacheManager.getOrganizationCache().put(mockKey, mockValue);

    System.Assert.areEqual(1, mockOrganizationPartitionProxy.putMethodCallCount);
    System.Assert.isTrue(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.areEqual(CacheManager.PLATFORM_CACHE_NULL_VALUE, mockOrganizationPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getOrganizationCache().get(mockKey));
  }

  @IsTest
  static void it_updates_value_for_existing_key_in_organization_cache_when_organization_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    User oldMockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.putMethodCallCount);
    CacheManager.getOrganizationCache().put(mockKey, oldMockValue);
    System.Assert.areEqual(1, mockOrganizationPartitionProxy.putMethodCallCount);
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.isTrue(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.areEqual(oldMockValue, CacheManager.getOrganizationCache().get(mockKey));
    Account newMockValue = new Account(Name = 'Some fake account');
    System.Assert.areEqual(1, mockOrganizationPartitionProxy.putMethodCallCount);

    CacheManager.getOrganizationCache().put(mockKey, newMockValue);

    System.Assert.areEqual(2, mockOrganizationPartitionProxy.putMethodCallCount);
    System.Assert.isTrue(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.areEqual(newMockValue, mockOrganizationPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(newMockValue, CacheManager.getOrganizationCache().get(mockKey));
  }

  @IsTest
  static void it_removes_value_for_existing_key_in_organization_cache_when_organization_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(mockKey));
    CacheManager.getOrganizationCache().put(mockKey, mockValue);
    System.Assert.isTrue(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.areEqual(mockValue, mockOrganizationPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getOrganizationCache().get(mockKey));
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.removeMethodCallCount);

    CacheManager.getOrganizationCache().remove(mockKey);

    System.Assert.areEqual(1, mockOrganizationPartitionProxy.removeMethodCallCount);
    System.Assert.isFalse(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(mockKey));
  }

  @IsTest
  static void it_removes_value_for_existing_key_in_organization_cache_when_organization_platform_cache_is_not_available() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(false);
    System.Assert.isFalse(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(mockKey));
    CacheManager.getOrganizationCache().put(mockKey, mockValue);
    System.Assert.isFalse(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.isNull(mockOrganizationPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getOrganizationCache().get(mockKey));
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.removeMethodCallCount);

    CacheManager.getOrganizationCache().remove(mockKey);

    System.Assert.areEqual(0, mockOrganizationPartitionProxy.removeMethodCallCount);
    System.Assert.isFalse(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(mockKey));
  }

  @IsTest
  static void it_does_not_remove_value_for_existing_key_in_organization_cache_when_organization_platform_cache_is_immutable() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(mockKey));
    CacheManager.getOrganizationCache().put(mockKey, mockValue);
    System.Assert.isTrue(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.areEqual(mockValue, mockOrganizationPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getOrganizationCache().get(mockKey));
    System.Assert.areEqual(0, mockOrganizationPartitionProxy.removeMethodCallCount);
    System.Assert.isFalse(CacheManager.getOrganizationCache().isImmutable());
    CacheManager.ORGANIZATION_CACHE_CONFIGURATION.IsImmutable__c = true;
    System.Assert.isTrue(CacheManager.getOrganizationCache().isImmutable());

    CacheManager.getOrganizationCache().remove(mockKey);

    System.Assert.areEqual(0, mockOrganizationPartitionProxy.removeMethodCallCount);
    System.Assert.isTrue(mockOrganizationPartitionProxy.contains(mockKey));
    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(mockKey));
  }

  @IsTest
  static void it_supports_bulk_operations_in_organization_cache() {
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.isTrue(CacheManager.getOrganizationCache().isAvailable());
    Map<String, Object> keyToValue = new Map<String, Object>{
      'SomeDate' => Date.newInstance(1999, 9, 9),
      'SomeString' => 'hello, world',
      'SomeSObject' => new User(Id = System.UserInfo.getUserId())
    };
    System.Assert.isFalse(CacheManager.getOrganizationCache().containsAll(new Set<String>()));
    System.Assert.isFalse(CacheManager.getOrganizationCache().containsAll(keyToValue.keySet()));
    CacheManager.getOrganizationCache().put(keyToValue);
    for (String key : keyToValue.keySet()) {
      System.Assert.isTrue(CacheManager.getOrganizationCache().contains(key));
    }
    System.Assert.isFalse(CacheManager.getOrganizationCache().containsAll(new Set<String>()));
    Map<String, Boolean> keyToContainsResult = CacheManager.getOrganizationCache().contains(keyToValue.keySet());
    for (String key : keyToContainsResult.keySet()) {
      Boolean containsResult = keyToContainsResult.get(key);
      System.Assert.isTrue(containsResult, 'Cache did not contain key: ' + key);
      System.Assert.isTrue(CacheManager.getOrganizationCache().contains(key));
    }
    Map<String, Object> returnedKeyToValue = CacheManager.getOrganizationCache().getAll();
    System.Assert.areEqual(keyToValue, returnedKeyToValue);
    System.Assert.isTrue(CacheManager.getOrganizationCache().containsAll(keyToValue.keySet()), '' + CacheManager.getOrganizationCache().getKeys());
    CacheManager.getOrganizationCache().remove(keyToValue.keySet());
    System.Assert.isFalse(CacheManager.getOrganizationCache().containsAll(keyToValue.keySet()));
  }

  @IsTest
  static void it_remove_alls_keys_in_organization_cache_when_remove_all_method_is_called() {
    MockPlatformCachePartitionProxy mockOrganizationPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockOrganizationPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.ORGANIZATION, mockOrganizationPartitionProxy);
    System.Assert.isTrue(CacheManager.getOrganizationCache().isAvailable());
    Map<String, Object> keyToValue = new Map<String, Object>{
      'SomeDate' => Date.newInstance(1999, 9, 9),
      'SomeString' => 'hello, world',
      'SomeSObject' => new User(Id = System.UserInfo.getUserId())
    };
    CacheManager.getOrganizationCache().put(keyToValue);
    System.Assert.areEqual(keyToValue.keySet(), CacheManager.getOrganizationCache().getKeys());

    CacheManager.getOrganizationCache().removeAll();

    System.Assert.isTrue(CacheManager.getOrganizationCache().getKeys().isEmpty());
  }

  @IsTest
  static void it_adds_new_key_to_session_cache_with_cachebuilder_when_session_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    System.Type cacheBuilderStubType = CacheBuilderStub.class;
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.areEqual(0, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.isFalse(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(1, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockSessionPartitionProxy.getCacheBuilderMethodCallCount);

    Object generatedValue = CacheManager.getSessionCache().get(mockKey, cacheBuilderStubType);

    System.Assert.areEqual(1, mockSessionPartitionProxy.getCacheBuilderMethodCallCount);
    System.Assert.isTrue(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.isNotNull(generatedValue);

    Object cachedValue = CacheManager.getSessionCache().get(mockKey, cacheBuilderStubType);

    System.Assert.isNotNull(cachedValue);
    System.Assert.areEqual(generatedValue, cachedValue);
    System.Assert.areEqual(1, mockSessionPartitionProxy.getCacheBuilderMethodCallCount);
    System.Assert.areEqual(cachedValue, mockSessionPartitionProxy.get(mockKey));
    System.Assert.isTrue(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(cachedValue, CacheManager.getSessionCache().get(mockKey));
  }

  @IsTest
  static void it_adds_new_key_to_fallback_transaction_cache_with_cachebuilder_when_session_platform_cache_is_not_available() {
    String mockKey = 'SomeKey';
    System.Type cacheBuilderStubType = CacheBuilderStub.class;
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(false);
    System.Assert.isFalse(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.areEqual(0, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.isFalse(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(0, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockSessionPartitionProxy.getCacheBuilderMethodCallCount);

    Object generatedValue = CacheManager.getSessionCache().get(mockKey, cacheBuilderStubType);

    System.Assert.areEqual(0, mockSessionPartitionProxy.getCacheBuilderMethodCallCount);
    System.Assert.isFalse(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.isNotNull(generatedValue);

    Object cachedValue = CacheManager.getSessionCache().get(mockKey, cacheBuilderStubType);

    System.Assert.isNotNull(cachedValue);
    System.Assert.areEqual(generatedValue, cachedValue);
    System.Assert.areEqual(0, mockSessionPartitionProxy.getCacheBuilderMethodCallCount);
    System.Assert.isNull(mockSessionPartitionProxy.get(mockKey));
    System.Assert.isFalse(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(cachedValue, CacheManager.getSessionCache().get(mockKey));
  }

  @IsTest
  static void it_adds_new_key_to_session_cache_when_session_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.areEqual(0, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.isFalse(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(1, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockSessionPartitionProxy.putMethodCallCount);

    CacheManager.getSessionCache().put(mockKey, mockValue);

    System.Assert.areEqual(1, mockSessionPartitionProxy.putMethodCallCount);
    System.Assert.isTrue(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.areEqual(mockValue, mockSessionPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getSessionCache().get(mockKey));
  }

  @IsTest
  static void it_adds_new_key_to_fallback_transaction_cache_when_session_platform_cache_is_not_available() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(false);
    System.Assert.isFalse(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.areEqual(0, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.isFalse(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(0, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockSessionPartitionProxy.putMethodCallCount);

    CacheManager.getSessionCache().put(mockKey, mockValue);

    System.Assert.areEqual(0, mockSessionPartitionProxy.putMethodCallCount);
    System.Assert.isFalse(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.isNull(mockSessionPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getSessionCache().get(mockKey));
  }

  @IsTest
  static void it_adds_configured_key_and_value_to_session_cache_when_session_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    CacheValue__mdt configuredCacheValue = new CacheValue__mdt(
      Cache__c = CacheManager.SESSION_CACHE_CONFIGURATION.Id,
      DataType__c = Schema.User.class.getName(),
      IsEnabled__c = true,
      Key__c = mockKey,
      Value__c = JSON.serialize(mockValue)
    );
    CacheManager.CONFIGURED_CACHE_VALUES.add(configuredCacheValue);
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);

    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    Object returnedValue = CacheManager.getSessionCache().get(mockKey);

    System.Assert.areEqual(mockValue, returnedValue);
    System.Assert.isInstanceOfType(returnedValue, Schema.User.class);
    System.Assert.areEqual(mockValue, mockSessionPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getSessionCache().get(mockKey));
  }

  @IsTest
  static void it_adds_configured_key_with_null_value_to_session_cache_when_session_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    CacheValue__mdt configuredCacheValue = new CacheValue__mdt(
      Cache__c = CacheManager.SESSION_CACHE_CONFIGURATION.Id,
      DataType__c = String.class.getName(),
      IsEnabled__c = true,
      Key__c = mockKey,
      Value__c = null
    );
    CacheManager.CONFIGURED_CACHE_VALUES.add(configuredCacheValue);
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);

    Object returnedValue = CacheManager.getSessionCache().get(mockKey);

    System.Assert.areEqual(null, returnedValue);
    System.Assert.areEqual(CacheManager.PLATFORM_CACHE_NULL_VALUE, mockSessionPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(null, CacheManager.getSessionCache().get(mockKey));
  }

  @IsTest
  static void it_adds_new_key_with_null_value_to_session_cache_when_session_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    User mockValue = null;
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.areEqual(0, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.isFalse(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(1, mockSessionPartitionProxy.containsMethodCallCount);
    System.Assert.areEqual(0, mockSessionPartitionProxy.putMethodCallCount);

    CacheManager.getSessionCache().put(mockKey, mockValue);

    System.Assert.areEqual(1, mockSessionPartitionProxy.putMethodCallCount);
    System.Assert.isTrue(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.areEqual(CacheManager.PLATFORM_CACHE_NULL_VALUE, mockSessionPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getSessionCache().get(mockKey));
  }

  @IsTest
  static void it_updates_value_for_existing_key_in_session_cache_when_session_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    User oldMockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.areEqual(0, mockSessionPartitionProxy.putMethodCallCount);
    CacheManager.getSessionCache().put(mockKey, oldMockValue);
    System.Assert.areEqual(1, mockSessionPartitionProxy.putMethodCallCount);
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.isTrue(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.areEqual(oldMockValue, CacheManager.getSessionCache().get(mockKey));
    Account newMockValue = new Account(Name = 'Some fake account');
    System.Assert.areEqual(1, mockSessionPartitionProxy.putMethodCallCount);

    CacheManager.getSessionCache().put(mockKey, newMockValue);

    System.Assert.areEqual(2, mockSessionPartitionProxy.putMethodCallCount);
    System.Assert.isTrue(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.areEqual(newMockValue, mockSessionPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(newMockValue, CacheManager.getSessionCache().get(mockKey));
  }

  @IsTest
  static void it_removes_value_for_existing_key_in_session_cache_when_session_platform_cache_is_available() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.isFalse(CacheManager.getSessionCache().contains(mockKey));
    CacheManager.getSessionCache().put(mockKey, mockValue);
    System.Assert.isTrue(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.areEqual(mockValue, mockSessionPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getSessionCache().get(mockKey));
    System.Assert.areEqual(0, mockSessionPartitionProxy.removeMethodCallCount);

    CacheManager.getSessionCache().remove(mockKey);

    System.Assert.areEqual(1, mockSessionPartitionProxy.removeMethodCallCount);
    System.Assert.isFalse(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.isFalse(CacheManager.getSessionCache().contains(mockKey));
  }

  @IsTest
  static void it_removes_value_for_existing_key_in_session_cache_when_session_platform_cache_is_not_available() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(false);
    System.Assert.isFalse(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.isFalse(CacheManager.getSessionCache().contains(mockKey));
    CacheManager.getSessionCache().put(mockKey, mockValue);
    System.Assert.isFalse(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.isNull(mockSessionPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getSessionCache().get(mockKey));
    System.Assert.areEqual(0, mockSessionPartitionProxy.removeMethodCallCount);

    CacheManager.getSessionCache().remove(mockKey);

    System.Assert.areEqual(0, mockSessionPartitionProxy.removeMethodCallCount);
    System.Assert.isFalse(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.isFalse(CacheManager.getSessionCache().contains(mockKey));
  }

  @IsTest
  static void it_does_not_remove_value_for_existing_key_in_session_cache_when_session_platform_cache_is_immutable() {
    String mockKey = 'SomeKey';
    User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.isFalse(CacheManager.getSessionCache().contains(mockKey));
    CacheManager.getSessionCache().put(mockKey, mockValue);
    System.Assert.isTrue(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.areEqual(mockValue, mockSessionPartitionProxy.get(mockKey));
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
    System.Assert.areEqual(mockValue, CacheManager.getSessionCache().get(mockKey));
    System.Assert.areEqual(0, mockSessionPartitionProxy.removeMethodCallCount);
    System.Assert.isFalse(CacheManager.getSessionCache().isImmutable());
    CacheManager.SESSION_CACHE_CONFIGURATION.IsImmutable__c = true;
    System.Assert.isTrue(CacheManager.getSessionCache().isImmutable());

    CacheManager.getSessionCache().remove(mockKey);

    System.Assert.areEqual(0, mockSessionPartitionProxy.removeMethodCallCount);
    System.Assert.isTrue(mockSessionPartitionProxy.contains(mockKey));
    System.Assert.isTrue(CacheManager.getSessionCache().contains(mockKey));
  }

  @IsTest
  static void it_supports_bulk_operations_in_session_cache() {
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.isTrue(CacheManager.getSessionCache().isAvailable());
    Map<String, Object> keyToValue = new Map<String, Object>{
      'SomeDate' => Date.newInstance(1999, 9, 9),
      'SomeString' => 'hello, world',
      'SomeSObject' => new User(Id = System.UserInfo.getUserId())
    };
    System.Assert.isFalse(CacheManager.getSessionCache().containsAll(new Set<String>()));
    System.Assert.isFalse(CacheManager.getSessionCache().containsAll(keyToValue.keySet()));
    CacheManager.getSessionCache().put(keyToValue);
    for (String key : keyToValue.keySet()) {
      System.Assert.isTrue(CacheManager.getSessionCache().contains(key));
    }
    System.Assert.isFalse(CacheManager.getSessionCache().containsAll(new Set<String>()));
    Map<String, Boolean> keyToContainsResult = CacheManager.getSessionCache().contains(keyToValue.keySet());
    for (String key : keyToContainsResult.keySet()) {
      Boolean containsResult = keyToContainsResult.get(key);
      System.Assert.isTrue(containsResult, 'Cache did not contain key: ' + key);
      System.Assert.isTrue(CacheManager.getSessionCache().contains(key));
    }
    Map<String, Object> returnedKeyToValue = CacheManager.getSessionCache().getAll();
    System.Assert.areEqual(keyToValue, returnedKeyToValue);
    System.Assert.isTrue(CacheManager.getSessionCache().containsAll(keyToValue.keySet()), '' + CacheManager.getSessionCache().getKeys());
    CacheManager.getSessionCache().remove(keyToValue.keySet());
    System.Assert.isFalse(CacheManager.getSessionCache().containsAll(keyToValue.keySet()));
  }

  @IsTest
  static void it_remove_alls_keys_in_session_cache_when_remove_all_method_is_called() {
    MockPlatformCachePartitionProxy mockSessionPartitionProxy = new MockPlatformCachePartitionProxy(true);
    System.Assert.isTrue(mockSessionPartitionProxy.isAvailable());
    CacheManager.setMockPartitionProxy(CacheManager.PlatformCacheType.SESSION, mockSessionPartitionProxy);
    System.Assert.isTrue(CacheManager.getSessionCache().isAvailable());
    Map<String, Object> keyToValue = new Map<String, Object>{
      'SomeDate' => Date.newInstance(1999, 9, 9),
      'SomeString' => 'hello, world',
      'SomeSObject' => new User(Id = System.UserInfo.getUserId())
    };
    CacheManager.getSessionCache().put(keyToValue);
    System.Assert.areEqual(keyToValue.keySet(), CacheManager.getSessionCache().getKeys());

    CacheManager.getSessionCache().removeAll();

    System.Assert.isTrue(CacheManager.getSessionCache().getKeys().isEmpty());
  }

  @IsTest
  static void it_does_not_impact_other_caches_when_organization_cache_is_updated() {
    String key = 'SomeKey';
    Object value = System.now();
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(key));
    System.Assert.isFalse(CacheManager.getSessionCache().contains(key));
    System.Assert.isFalse(CacheManager.getTransactionCache().contains(key));

    CacheManager.getOrganizationCache().put(key, value);

    System.Assert.isTrue(CacheManager.getOrganizationCache().contains(key));
    System.Assert.areEqual(value, CacheManager.getOrganizationCache().get(key));
    System.Assert.isFalse(CacheManager.getSessionCache().contains(key));
    System.Assert.isFalse(CacheManager.getTransactionCache().contains(key));
  }

  @IsTest
  static void it_does_not_impact_other_caches_when_session_cache_is_updated() {
    String key = 'SomeKey';
    Object value = System.now();
    System.Assert.isFalse(CacheManager.getSessionCache().contains(key));
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(key));
    System.Assert.isFalse(CacheManager.getTransactionCache().contains(key));

    CacheManager.getSessionCache().put(key, value);

    System.Assert.isTrue(CacheManager.getSessionCache().contains(key));
    System.Assert.areEqual(value, CacheManager.getSessionCache().get(key));
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(key));
    System.Assert.isFalse(CacheManager.getTransactionCache().contains(key));
  }

  @IsTest
  static void it_does_not_impact_other_caches_when_transaction_cache_is_updated() {
    String key = 'SomeKey';
    Object value = System.now();
    System.Assert.isFalse(CacheManager.getTransactionCache().contains(key));
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(key));
    System.Assert.isFalse(CacheManager.getSessionCache().contains(key));

    CacheManager.getTransactionCache().put(key, value);

    System.Assert.isTrue(CacheManager.getTransactionCache().contains(key));
    System.Assert.areEqual(value, CacheManager.getTransactionCache().get(key));
    System.Assert.isFalse(CacheManager.getOrganizationCache().contains(key));
    System.Assert.isFalse(CacheManager.getSessionCache().contains(key));
  }

  @IsTest
  static void validateKey_does_not_throw_when_called_with_number() {
    try {
      for (Integer i = 0; i < 50; ++i) {
        CacheManager.validateKey('' + i);
      }
      System.Assert.isTrue(true);
    } catch (IllegalArgumentException ex) {
      System.Assert.fail();
    }
  }

  @IsTest
  static void validateKey_does_not_throw_when_called_with_letters() {
    String alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    try {
      for (String key : alphabet.split('')) {
        CacheManager.validateKey(key);
      }
      System.Assert.isTrue(true);
    } catch (IllegalArgumentException ex) {
      System.Assert.fail();
    }
  }

  @IsTest
  static void validateKey_throws_when_called_with_not_letters_nor_numbers() {
    String otherChars = 'ù%`$€"\'(§!)-&@"#éèàç*¨ %£+/=.?,\\';

    for (String key : otherChars.split('')) {
      try {
        CacheManager.validateKey(key);
        System.Assert.fail();
      } catch (Exception ex) {
        System.Assert.isInstanceOfType(ex, IllegalArgumentException.class);
      }
    }
  }

  @IsTest
  static void validateKey_throws_when_called_with_not_letters_nor_numbers_and_letter_numbers() {
    List<String> phrase = new List<String>{ 'I throw !!', 'I throw 2 times for sure!!', 'No, you throw' };

    for (String key : phrase) {
      try {
        CacheManager.validateKey(key);
        System.Assert.fail();
      } catch (Exception ex) {
        System.Assert.isInstanceOfType(ex, IllegalArgumentException.class);
      }
    }
  }

  // Since the class `Cache.Partition` can't have be mocked & can't have its methods overridden,
  // the `CacheManager` class internally uses a proxy to help abstract out the usage of the partition,
  // which lets us mock the proxy within (true) unit tests.
  private class MockPlatformCachePartitionProxy extends CacheManager.PlatformCachePartitionProxy {
    private final Boolean isAvailable;
    // Since `Cache.Partition` can't be mocked, this mock proxy uses a map as a substitute
    private final Map<String, Object> keyToValue = new Map<String, Object>();

    public Integer isAvailableMethodCallCount = 0;
    public Integer containsMethodCallCount = 0;
    public Integer getMethodCallCount = 0;
    public Integer getCacheBuilderMethodCallCount = 0;
    public Integer putMethodCallCount = 0;
    public Integer removeMethodCallCount = 0;

    private MockPlatformCachePartitionProxy(Boolean isAvailable) {
      super(null, null);
      this.isAvailable = isAvailable;
    }

    public override Boolean isAvailable() {
      this.isAvailableMethodCallCount++;
      return this.isAvailable;
    }

    public override Boolean contains(String key) {
      this.containsMethodCallCount++;
      return this.keyToValue.containsKey(key);
    }

    public override Object get(String key) {
      this.getMethodCallCount++;
      return this.keyToValue.get(key);
    }

    public override Object get(String key, System.Type cacheBuilderClass) {
      this.getCacheBuilderMethodCallCount++;
      if (this.keyToValue.containsKey(key) == false) {
        Cache.CacheBuilder cacheBuilder = (Cache.CacheBuilder) cacheBuilderClass.newInstance();
        Object value = cacheBuilder.doLoad(key);
        this.keyToValue.put(key, value);
      }
      return this.keyToValue.get(key);
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public override void put(String key, Object value, Integer cacheTtlSeconds, Cache.Visibility cacheVisiblity, Boolean isCacheImmutable) {
      this.putMethodCallCount++;
      this.keyToValue.put(key, value);
    }

    public override void remove(String key) {
      this.removeMethodCallCount++;
      this.keyToValue.remove(key);
    }
  }

  private class CacheBuilderStub implements Cache.CacheBuilder {
    public Object doLoad(String key) {
      User mockValue = new User(Id = System.UserInfo.getUserId(), ProfileId = System.UserInfo.getProfileId());
      return mockValue;
    }
  }
}
