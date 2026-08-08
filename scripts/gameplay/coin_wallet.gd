class_name CoinWalletStore
extends Node

signal total_coins_changed(total: int)

var total_coins := 0


func add_coins(amount: int) -> int:
	if amount <= 0:
		return total_coins
	total_coins += amount
	total_coins_changed.emit(total_coins)
	return total_coins


func get_total_coins() -> int:
	return total_coins


func reset_for_tests() -> void:
	total_coins = 0
	total_coins_changed.emit(total_coins)
