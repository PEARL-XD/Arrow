/// Store-funded coins are separate from offline gameplay rewards.
abstract interface class PaidWallet {
  int get balance;
  Future<Map<String, dynamic>> spend(Map<String, dynamic> request);
  Future<void> acknowledge(String id);
  Future<void> refresh();
}
