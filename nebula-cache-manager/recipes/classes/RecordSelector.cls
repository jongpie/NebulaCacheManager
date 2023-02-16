@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc, PMD.EmptyStatementBlock')
public without sharing class RecordSelector {
  public RecordSelector() {
  }

  public User getCurrentUser() {
    String cacheKey = 'user_' + System.UserInfo.getUserId();
    if (CacheManager.getSessionCache().contains(cacheKey) == true) {
      return (User) CacheManager.getSessionCache().get(cacheKey);
    }

    User currentUser = [
      SELECT Id, Email, FirstName, LastName, ProfileId, Profile.Name, Username, UserRoleId, UserRole.Name
      FROM User
      WHERE Id = :System.UserInfo.getUserId()
    ];
    CacheManager.getSessionCache().put(cacheKey, currentUser);
    return currentUser;
  }

  public List<Group> getQueues() {
    String cacheKey = 'queues';
    if (CacheManager.getOrganizationCache().contains(cacheKey) == true) {
      return (List<Group>) CacheManager.getOrganizationCache().get(cacheKey);
    }

    List<Group> queues = [SELECT Id FROM Group WHERE Type = 'Queue'];
    CacheManager.getOrganizationCache().put(cacheKey, queues);
    return queues;
  }
}
