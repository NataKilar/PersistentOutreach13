/obj/machinery/computer/exonet/security
	name = "\improper Security console"
	ui_template = "exonet_security_console.tmpl"

/obj/machinery/computer/exonet/security/OnTopic(var/mob/user, var/href_list, var/datum/topic_state/state)


/obj/machinery/computer/exonet/security/build_ui_data()
	. = ..()
