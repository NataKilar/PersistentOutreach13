/obj/machinery/computer/exonet/command
	name = "\improper Command console"
	ui_template = "exonet_command_console.tmpl"
	var/datum/exonet/exonet

/obj/machinery/computer/exonet/command/Initialize()
	if(!exonet) // not a save rebuild?
		exonet = GLOB.exonets.get_exonet_by_area(get_area(loc))
		if(!exonet) // Is this ALL NEW EXONET???
			exonet = new()

/obj/machinery/computer/exonet/command/Destroy()
	..()
	qdel(exonet)

/obj/machinery/computer/exonet/command/OnTopic(var/mob/user, var/href_list, var/datum/topic_state/state)


/obj/machinery/computer/exonet/command/build_ui_data()
	. = ..()
