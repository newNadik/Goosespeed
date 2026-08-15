class_name CoinWalletStore
extends Node

signal total_coins_changed(total: int)

const SAVE_PATH := "user://goosespeed_wallet.cfg"
const SECTION := "wallet"
const TOTAL_COINS_KEY := "total_coins"

var total_coins := 0


func _ready() -> void:
	load_wallet()


func load_wallet() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		total_coins = 0
		return
	total_coins = maxi(int(config.get_value(SECTION, TOTAL_COINS_KEY, 0)), 0)


func save_wallet() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, TOTAL_COINS_KEY, total_coins)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Failed to save GooseSpeed wallet: %s" % error)


func add_coins(amount: int) -> int:
	if amount <= 0:
		return total_coins
	total_coins += amount
	save_wallet()
	total_coins_changed.emit(total_coins)
	return total_coins


func get_total_coins() -> int:
	return total_coins


func reset_for_tests() -> void:
	total_coins = 0
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(absolute_path):
		var error := DirAccess.remove_absolute(absolute_path)
		if error != OK:
			push_warning("Failed to remove GooseSpeed wallet test save: %s" % error)
	total_coins_changed.emit(total_coins)
