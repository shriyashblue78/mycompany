import '../models/transaction_type_model.dart';

abstract class TransactionTypeRepository {
  Future<void> createTransactionType(String companyId, TransactionTypeModel type);
  Future<void> updateTransactionType(String companyId, TransactionTypeModel type);
  Future<void> deleteTransactionType(String companyId, String typeId);
  Stream<List<TransactionTypeModel>> streamTransactionTypes(String companyId);
  Future<bool> isTypeNameTaken(String companyId, String typeName, {String? excludeTypeId});
}
