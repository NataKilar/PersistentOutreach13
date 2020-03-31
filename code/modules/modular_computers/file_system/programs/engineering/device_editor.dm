/datum/computer_file/program/device_editor
	filename = "device_editor"
	filedesc = "Device Editor"
	extended_desc = "This program can be used to connect to devices over near-field communication for programming."
	program_icon_state = "generic"
	program_key_state = "generic_key"
	program_menu_icon = "note"
	size = 12
	requires_exonet = 1

	nanomodule_path = /datum/nano_module/program/device_editor

	var/error = ""

/datum/nano_module/program/device_editor
	name = "NTOS Device Editor"

/datum/nano_module/program/device_editor/proc/get_functional_network_card()
	var/datum/extension/interactive/ntos/os = get_extension(nano_host(), /datum/extension/interactive/ntos)
	var/obj/item/weapon/stock_parts/computer/network_card/network_card = os && os.get_component(/obj/item/weapon/stock_parts/computer/network_card)
	if(!network_card || !network_card.check_functionality())
		// error = "Error establishing connection. Are you using a functional and NTOSv2-compliant device?"
		return
	return network_card


/datum/nano_module/program/device_editor/proc/get_all_grants()
	var/list/grants = list()
	var/network_card = get_functional_network_card()
	if(!network_card)
		return grants
	var/datum/extension/exonet_device/exonet = get_extension(network_card, /datum/extension/exonet_device)
	for(var/obj/machinery/computer/exonet/mainframe/mainframe in exonet.get_mainframes())
		if(!mainframe.operable())
			continue
		for(var/datum/computer_file/data/grant_record/GR in mainframe.stored_files)
			grants.Add(GR)
	return grants

/datum/nano_module/program/device_editor/proc/get_functional_programmer()
	var/datum/extension/interactive/ntos/os = get_extension(nano_host(), /datum/extension/interactive/ntos)
	var/obj/item/weapon/stock_parts/computer/rfid_programmer/programmer = os && os.get_component(/obj/item/weapon/stock_parts/computer/rfid_programmer)
	if(!programmer || !programmer.check_functionality())
		//program.error = "Error finding RFID Programmer. Are you using a functional and NTOSv2-compliant device?"
		return
	return programmer

/datum/nano_module/program/device_editor/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1, var/datum/topic_state/state = GLOB.default_state)
	var/list/data = host.initial_data()
	var/datum/computer_file/program/device_editor/PRG
	PRG = program

	var/obj/item/weapon/stock_parts/computer/rfid_programmer/programmer = get_functional_programmer()
	var/datum/linked_device = programmer.get_device()
	if(!linked_device)
		PRG.error = "No device currently linked or out of range."

	if(PRG.error)
		data["error"] = PRG.error

	if(linked_device)
		// We have a linked device. Time to set up data.
		if(istype(linked_device, /obj/item/weapon/stock_parts/exonet_lock))
			var/obj/item/weapon/stock_parts/exonet_lock/lock = linked_device
			// Device is an exonet lock. Assign those vars.
			data["ennid"] = lock.ennid ? lock.ennid : "Not Set"
			data["key"] = lock.keydata ? lock.keydata : "Not Set"
			data["status"] = "High Strength"
			data["enabled"] = lock.tightened
			data["default_state"] = lock.auto_deny_all
			var/list/grants = list()
			for(var/datum/computer_file/data/grant_record/GR in get_all_grants())
				grants.Add(list(list(
					"grant_name" = GR.stored_data,
					"assigned" = (GR in lock.grants)
				)))
			data["grants"] = grants

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "device_editor.tmpl", "NTOS Device Editor", 600, 700, state = state)
		ui.auto_update_layout = 1
		ui.set_initial_data(data)
		ui.open()