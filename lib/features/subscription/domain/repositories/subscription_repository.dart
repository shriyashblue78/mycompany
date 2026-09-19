import '../models/company_subscription_model.dart';

abstract class SubscriptionRepository {
  Future<CompanySubscriptionModel?> getCompanySubscription(String companyId);
  Stream<CompanySubscriptionModel?> streamCompanySubscription(String companyId);
  Future<void> setCompanySubscription(CompanySubscriptionModel subscription);
  Future<void> updateCompanySubscription(CompanySubscriptionModel subscription);
}
