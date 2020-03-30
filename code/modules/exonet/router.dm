/obj/machinery/computer/exonet/broadcaster/router
	name = "EXONET Router"
	desc = "A very complex router and transmitter capable of connecting electronic devices together. Looks fragile."
	active_power_usage = 8 KILOWATTS
	ui_template = "exonet_router_configuration.tmpl"
	var/lockdata				// Network security. This key is required to join a network device to the network.
	var/dos_failure = 0			// Set to 1 if the router failed due to (D)DoS attack
	var/list/dos_sources = list()	// Backwards reference for qdel() stuff

	// Denial of Service attack variables
	var/dos_overload = 0		// Amount of DoS "packets" in this relay's buffer
	var/dos_capacity = 500		// Amount of DoS "packets" in buffer required to crash the relay
	var/dos_dissipate = 1		// Amount of DoS "packets" dissipated over time.

	var/datum/exonet/network	// This is a hard reference back to the attached network. Primarily for serialization purposes on persistence.

	var/error					// Error to display on the interface.

/obj/machinery/computer/exonet/broadcaster/router/Initialize()
	. = ..()
	if(!broadcasting_ennid)
		broadcasting_ennid = ennid
	if(broadcasting_ennid)
		// Sets up the network before anything else can. go go go go
		var/datum/extension/exonet_device/exonet = get_extension(src, /datum/extension/exonet_device)
		exonet.broadcast_network(broadcasting_ennid, lockdata)
		network = exonet.get_local_network()

	// if(dos_overload)
	// 	dos_overload = max(0, dos_overload - dos_dissipate)

	// // If DoS traffic exceeded capacity, crash.
	// if((dos_overload > dos_capacity) && !dos_failure)
	// 	dos_failure = 1
	// 	update_icon()
	// 	var/datum/extension/exonet_device/exonet = get_extension(src, /datum/extension/exonet_device)
	// 	var/datum/exonet/network = exonet.get_local_network()
	// 	network.add_log("EXONET router switched from normal operation mode to overload recovery mode.")
	// // If the DoS buffer reaches 0 again, restart.
	// if((dos_overload == 0) && dos_failure)
	// 	dos_failure = 0
	// 	update_icon()
	// 	var/datum/extension/exonet_device/exonet = get_extension(src, /datum/extension/exonet_device)
	// 	var/datum/exonet/network = exonet.get_local_network()
	// 	network.add_log("EXONET router switched from overload recovery mode to normal operation mode.")

/obj/machinery/computer/exonet/broadcaster/router/build_ui_data()
	. = ..()

	if(error)
		.["error"] = error
		return .

	.["signal_strength"] = signal_strength
	if(broadcasting_ennid)
		.["ennid"] = broadcasting_ennid
	else
		.["ennid"] = "Not Set"
	if(lockdata)
		.["key"] = "******************"
	else
		.["key"] = "Not Set"
	if(broadcasting_ennid && operable())
		.["broadcasting_status"] = "Active"
	else
		.["broadcasting_status"] = "Down"
	.["power_usage"] = active_power_usage / 1000

/obj/machinery/computer/exonet/broadcaster/router/Topic(href, href_list)
	if(..())
		return TOPIC_HANDLED
	var/datum/extension/exonet_device/exonet = get_extension(src, /datum/extension/exonet_device)
	if(href_list["PRG_newennid"])
		// When a router's ennid changes, so does the network. Breaking *literally everything*.
		var/new_ennid = sanitize(input(usr, "Enter a new ennid or leave blank to cancel:", "Change ENNID"))
		if(!new_ennid)
			return TOPIC_HANDLED
		// Do a unique check...
		for(var/datum/exonet/E in GLOB.exonets)
			if(E.ennid == new_ennid)
				error = "Invalid ENNID. This ENNID is already registered."
				return TOPIC_HANDLED
		// time to break everything...
		network = exonet.get_local_network()
		if(network)
			network.change_ennid(new_ennid)
		broadcasting_ennid = new_ennid
		exonet.broadcast_network(broadcasting_ennid, lockdata)
	if(href_list["PRG_back"])
		error = null

// 	if(..())
// 		return 1
// 	if(href_list["restart"])
// 		dos_overload = 0
// 		dos_failure = 0
// 		update_icon()
// 		var/datum/extension/exonet_device/exonet = get_extension(src, /datum/extension/exonet_device)
// 		var/datum/exonet/network = exonet.get_local_network()
// 		network.add_log("EXONET router manually restarted from overload recovery mode to normal operation mode.")
// 		return 1
// 	else if(href_list["toggle"])
// 		enabled = !enabled
// 		var/datum/extension/exonet_device/exonet = get_extension(src, /datum/extension/exonet_device)
// 		var/datum/exonet/network = exonet.get_local_network()
// 		network.add_log("EXONET router manually [enabled ? "enabled" : "disabled"].")
// 		update_icon()
// 		return 1
// 	else if(href_list["purge"])
// 		// ntnet_global.banned_nids.Cut()
// 		var/datum/extension/exonet_device/exonet = get_extension(src, /datum/extension/exonet_device)
// 		var/datum/exonet/network = exonet.get_local_network()
// 		network.add_log("Manual override: Network blacklist cleared.")
// 		return 1
// 	else if(href_list["eject_drive"] && uninstall_component(/obj/item/weapon/stock_parts/computer/hard_drive/portable))
// 		visible_message("\icon[src] [src] beeps and ejects its portable disk.")

// /obj/machinery/computer/exonet/broadcaster/router/attackby(obj/item/P, mob/user)
// 	if (!istype(P,/obj/item/weapon/stock_parts/computer/hard_drive/portable))
// 		return
// 	else if (get_component_of_type(/obj/item/weapon/stock_parts/computer/hard_drive/portable))
// 		to_chat(user, "This relay's portable drive slot is already occupied.")
// 	else if(user.unEquip(P,src))
// 		install_component(P)
// 		to_chat(user, "You install \the [P] into \the [src]")

// /obj/machinery/computer/exonet/broadcaster/router/OnTopic(var/mob/user, var/href_list, var/datum/topic_state/state)