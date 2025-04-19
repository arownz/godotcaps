extends Control

var COLLECTION_ID = "panda_stats"
var UnlockedUpgrades: Dictionary = {}

var petting_count: int = 0:
	set(value):
		petting_count = value
		%PettingCountLabel.text = str(value)
		
# Called when the node enters the scene tree for the first time.
func _ready():
	load_data()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_panda_button_pressed():
	petting_count += 1


func _on_logout_button_pressed():
	Firebase.Auth.logout()
	get_tree().change_scene_to_file("res://Authentication.tscn")


func _on_save_button_pressed():
	save_data()
	
func save_data():
	print("Total " + str(petting_count) )
	var auth = Firebase.Auth.auth
	
	if auth.localid:
		var collection: FirestoreCollection = Firebase.Firestore.collection(COLLECTION_ID)
		var data: Dictionary = {
			"Upgrades": UnlockedUpgrades
		}
		# Fetch the document reference using the localid
		var document = await collection.get_doc(auth.localid)
		
		# If the document exists, update it with the data dictionary
		if document:
			for key in data.keys():
				document.add_or_update_field(key, data[key])
			var task = await collection.update(document)
			if task:
				print("Document updated successfully")
			else:
				print("Failed to update document")
		else:
			# If the document does not exist, create a new one
			document = await collection.add(auth.localid, data)
			if document:
				print("Document created successfully")
			else:
				print("Failed to create document")

func load_data():
	var auth = Firebase.Auth.auth
	
	if auth.localid:
		var collection: FirestoreCollection = Firebase.Firestore.collection(COLLECTION_ID)
		
		# Await the task to get the document
		var document = await collection.get_doc(auth.localid)
		
		if document:
			# Print the document data
			print(document)
		
			var upgrades = document.get_value("Upgrades")
			if upgrades:
				UnlockedUpgrades = upgrades

			print("Upgrades: ", upgrades)
			print("Upgrades: ", upgrades)
		else:
			print("Failed to load document")
	
