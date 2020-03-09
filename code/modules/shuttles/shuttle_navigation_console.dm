/obj/machinery/computer/shuttle_nav
	name = "shuttle navigation console"
	icon = 'icons/obj/computer.dmi'
	icon_keyboard = "atmos_key"
	icon_screen = "shuttle"
	base_type = /obj/machinery/computer/shuttle_nav

	var/shuttle_tag  // Used to coordinate data in shuttle controller.
	var/eye_type = /mob/observer/eye/shuttle
	var/mob/observer/eye/shuttle/eyeobj = null
	var/datum/visualnet/shuttlenet/visualnet = null
	var/eye_active = FALSE

/obj/machinery/computer/shuttle_nav/interface_interact(var/mob/user)
	ui_interact(user)
	return TRUE

/obj/machinery/computer/shuttle_nav/ui_interact(var/mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open=1)
	var/list/data = list()

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "shuttle_nav_console.tmpl", "Shuttle Nav Console", 600, 800)
		ui.set_initial_data(data)
		ui.open()

/obj/machinery/computer/shuttle_nav/OnTopic(var/mob/user, href_list, state)
	if(href_list["camera"])
		. = TOPIC_REFRESH
		if(eye_active)
			//user.unset_machine()
			destroy_eye()
		else
			//user.set_machine(src)
			create_eye(user)

/*
/obj/machinery/computer/shuttle_nav/check_eye(mob/user)
	if(!eye_active)
		return 0
	return SEE_TURFS
*/

/obj/machinery/computer/shuttle_nav/proc/create_eye(var/mob/user)
	visualnet = new /datum/visualnet/shuttlenet
	eyeobj = new eye_type(get_turf(src), visualnet)
	eyeobj.possess(user)
	eyeobj.visualnet.add_source(src)
	eye_active = TRUE

/obj/machinery/computer/shuttle_nav/proc/destroy_eye()
	QDEL_NULL(eyeobj)
	QDEL_NULL(visualnet)
	eye_active = FALSE
