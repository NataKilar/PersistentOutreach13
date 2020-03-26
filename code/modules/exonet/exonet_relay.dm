// Relays don't handle any actual communication. Global NTNet datum does that, relays only tell the datum if it should or shouldn't work.
/obj/machinery/exonet_relay
	name = "EXONET Quantum Relay"
	desc = "A very complex router and transmitter capable of connecting electronic devices together. Looks fragile."
	use_power = POWER_USE_ACTIVE
	active_power_usage = 20000 //20kW, apropriate for machine that keeps massive cross-Zlevel wireless network operational.
	idle_power_usage = 100
	icon_state = "bus"
	anchored = 1
	density = 1
	construct_state = /decl/machine_construction/default/panel_closed
	uncreated_component_parts = null
	stat_immune = 0
	var/datum/exonet/exonet = null // This is mostly for backwards reference and to allow varedit modifications from ingame.
	var/enabled = 1				// Set to 0 if the relay was turned off
	var/dos_failure = 0			// Set to 1 if the relay failed due to (D)DoS attack
	var/list/dos_sources = list()	// Backwards reference for qdel() stuff

	// Denial of Service attack variables
	var/dos_overload = 0		// Amount of DoS "packets" in this relay's buffer
	var/dos_capacity = 500		// Amount of DoS "packets" in buffer required to crash the relay
	var/dos_dissipate = 1		// Amount of DoS "packets" dissipated over time.


// TODO: Implement more logic here. For now it's only a placeholder.
/obj/machinery/exonet_relay/operable()
	if(!..(EMPED))
		return 0
	if(dos_failure)
		return 0
	if(!enabled)
		return 0
	return 1

/obj/machinery/exonet_relay/on_update_icon()
	if(operable())
		icon_state = "bus"
	else
		icon_state = "bus_off"

/obj/machinery/exonet_relay/Process()
	if(operable())
		update_use_power(POWER_USE_ACTIVE)
	else
		update_use_power(POWER_USE_IDLE)

	if(dos_overload)
		dos_overload = max(0, dos_overload - dos_dissipate)

	// If DoS traffic exceeded capacity, crash.
	if((dos_overload > dos_capacity) && !dos_failure)
		dos_failure = 1
		update_icon()
		ntnet_global.add_log("Quantum relay switched from normal operation mode to overload recovery mode.")
	// If the DoS buffer reaches 0 again, restart.
	if((dos_overload == 0) && dos_failure)
		dos_failure = 0
		update_icon()
		ntnet_global.add_log("Quantum relay switched from overload recovery mode to normal operation mode.")

/obj/machinery/exonet_relay/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1, var/datum/topic_state/state = GLOB.default_state)
	var/list/data = list()
	data["enabled"] = enabled
	data["dos_capacity"] = dos_capacity
	data["dos_overload"] = dos_overload
	data["dos_crashed"] = dos_failure
	data["portable_drive"] = !!get_component_of_type(/obj/item/stock_parts/computer/hard_drive/portable)

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "ntnet_relay.tmpl", "EXONET Quantum Relay", 500, 300, state = state)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/obj/machinery/exonet_relay/interface_interact(var/mob/living/user)
	ui_interact(user)
	return TRUE

/obj/machinery/exonet_relay/Topic(href, href_list)
	if(..())
		return 1
	if(href_list["restart"])
		dos_overload = 0
		dos_failure = 0
		update_icon()
		ntnet_global.add_log("Quantum relay manually restarted from overload recovery mode to normal operation mode.")
		return 1
	else if(href_list["toggle"])
		enabled = !enabled
		ntnet_global.add_log("Quantum relay manually [enabled ? "enabled" : "disabled"].")
		update_icon()
		return 1
	else if(href_list["purge"])
		ntnet_global.banned_nids.Cut()
		ntnet_global.add_log("Manual override: Network blacklist cleared.")
		return 1
	else if(href_list["eject_drive"] && uninstall_component(/obj/item/stock_parts/computer/hard_drive/portable))
		visible_message("\icon[src] [src] beeps and ejects its portable disk.")

/obj/machinery/exonet_relay/Initialize()
	. = ..()
	uid = gl_uid
	gl_uid++
	var/datum/exonet/local_exonet = GLOB.exonets.get_exonet_by_area(get_area(loc))
	if(local_exonet)
		local_exonet.relays.Add(src)
		exonet = local_exonet
		local_exonet.add_log("New quantum relay activated. Current amount of linked relays: [NTNet.relays.len]")

/obj/machinery/exonet_relay/Destroy()
	if(exonet)
		exonet.relays.Remove(src)
		exonet.add_log("Quantum relay connection severed. Current amount of linked relays: [NTNet.relays.len]")
		exonet = null
	for(var/datum/computer_file/program/ntnet_dos/D in dos_sources)
		D.target = null
		D.error = "Connection to quantum relay severed"
	..()

/obj/machinery/exonet_relay/attackby(obj/item/P, mob/user)
	if (!istype(P,/obj/item/stock_parts/computer/hard_drive/portable))
		return
	else if (get_component_of_type(/obj/item/stock_parts/computer/hard_drive/portable))
		to_chat(user, "This relay's portable drive slot is already occupied.")
	else if(user.unEquip(P,src))
		install_component(P)
		to_chat(user, "You install \the [P] into \the [src]")