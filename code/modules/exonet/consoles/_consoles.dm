/obj/machinery/computer/exonet
	icon_keyboard = "power_key"
	light_color = COLOR_BLUE_GRAY
	idle_power_usage = 250
	active_power_usage = 500
	var/ui_template
	var/initial_id_tag

/obj/machinery/computer/exonet/attackby(var/obj/item/thing, var/mob/user)
	return ..()

/obj/machinery/computer/exonet/interface_interact(var/mob/user)
	ui_interact(user)
	return TRUE

/obj/machinery/computer/exonet/proc/build_ui_data()
	// var/datum/extension/local_network_member/fusion = get_extension(src, /datum/extension/local_network_member)
	// var/datum/local_network/lan = fusion.get_local_network()
	var/list/data = list()
	// data["id"] = lan ? lan.id_tag : "unset"
	// data["name"] = name
	. = data

/obj/machinery/computer/exonet/ui_interact(var/mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1)
	if(ui_template)
		var/list/data = build_ui_data()
		ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
		if (!ui)
			ui = new(user, src, ui_key, ui_template, name, 400, 600)
			ui.set_initial_data(data)
			ui.open()
			ui.set_auto_update(1)