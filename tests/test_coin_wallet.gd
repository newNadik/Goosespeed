extends Node


func _ready() -> void:
	if CoinWallet.has_method("reset_for_tests"):
		CoinWallet.reset_for_tests()
	CoinWallet.load_wallet()

	if CoinWallet.get_total_coins() != 0:
		push_error("CoinWallet should start empty after test reset")
		get_tree().quit(1)
		return
	if CoinWallet.add_coins(12) != 12:
		push_error("CoinWallet did not add coins")
		get_tree().quit(1)
		return
	if CoinWallet.add_coins(0) != 12 or CoinWallet.add_coins(-3) != 12:
		push_error("CoinWallet accepted non-positive coins")
		get_tree().quit(1)
		return

	CoinWallet.load_wallet()
	if CoinWallet.get_total_coins() != 12:
		push_error("CoinWallet did not reload saved total")
		get_tree().quit(1)
		return

	CoinWallet.reset_for_tests()
	print("Coin wallet OK")
	get_tree().quit(0)
