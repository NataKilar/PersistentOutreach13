/obj/machinery/door/airlock/rentalock
	var/keycode								// An alphanumeric password that can unlock the door.
	var/price			= 3000				// How much it costs to rent this airlock.
	var/expiration							// When the rent expires.
	var/renter_name		= null				// Who rented.


/obj/machinery/door/airlock/rentalock/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1, var/datum/topic_state/state = GLOB.default_state)
	var/list/data = list()

	data["locked"] = locked
	data["can_deposit"] = TRUE
	data["rented"] = !!renter_name
	data["rented_by"] = renter_name
	data["rented_for"] = "23 HOURS, 18 MINUTES REMAINING"
	data["price"] = price

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "rentalock.tmpl", "Door Controls", 450, 350, state = state)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/obj/machinery/door/airlock/rentalock/Topic(href, href_list)
	if(..())
		return TOPIC_HANDLED

	. = TOPIC_HANDLED
	if(href_list["unlock"])
		src.unlock()
		to_chat(usr, "The door bolts have been raised.")
	if(href_list["lock"])
		src.lock()
		to_chat(usr, "The door bolts have been dropped.")
	if(href_list["rent"])
		renter_name = usr.name
		expiration = world.realtime + 259200 SECONDS
		to_chat(usr, "The door affirmatively beeps as rent is deposited.")