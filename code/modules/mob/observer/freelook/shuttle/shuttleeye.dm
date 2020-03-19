/mob/observer/eye/shuttle
	name = "Shuttle Docking Eye"
	desc = "A visual projection used to assist in the docking of a shuttle."
	var/datum/shuttle/autodock/shuttle/
	var/list/landing_images = list()

/mob/observer/eye/shuttle/New(var/loc, var/net, var/shuttle_tag)
	..()
	visualnet = net
	shuttle = SSshuttle.shuttles[shuttle_tag]

	var/turf/origin = get_turf(src)
	for(var/area/A in shuttle.shuttle_area)
		for(var/turf/T in A)
			var/image/I = image('icons/effects/alphacolors.dmi', origin, "red")
			// Record the offset of the turfs from the eye. The eye is where the shuttle landmark will be placed, so the resultant images will reflect actual landing.
			var/x_off = T.x - origin.x
			var/y_off = T.y - origin.y

			I.loc = locate(origin.x + x_off, origin.y + y_off, origin.z)
			I.plane = OBSERVER_PLANE
			landing_images[I] = list(x_off, y_off)

/mob/observer/eye/shuttle/Destroy()
	shuttle = null
	if(owner) owner.client.images -= landing_images
	QDEL_NULL(landing_images)
	. = ..()

/mob/observer/eye/shuttle/setLoc(var/T)
	..()
	check_landing()

/mob/observer/eye/shuttle/proc/check_landing()
	for(var/i = 1; i < landing_images.len; i++)
		var/image/img = landing_images[i]
		var/list/coords = landing_images[img]

		var/turf/origin = get_turf(src)
		var/turf/T = locate(origin.x + coords[1], origin.y + coords[2], origin.z)
		img.loc = T

		img.icon_state = "green"
		. = TRUE

		if(!T)
			img.icon_state = "red"
			return FALSE // Cannot collide with the edge of the map.
		if(T.loc != get_area(src))
			img.icon_state = "red"
			return FALSE // Cannot cross between two areas.
		if(T.density)
			img.icon_state = "red"
			return FALSE // Cannot land on a dense turf.

/mob/observer/eye/shuttle/possess(var/mob/user)
	..()
	if(owner)
		LAZYDISTINCTADD(owner.additional_vision_handlers, src)
		if(owner.client)
			owner.client.view = world.view + 3

		owner.client.images += landing_images

/mob/observer/eye/shuttle/release(var/mob/user)
	if(owner)
		LAZYREMOVE(user.additional_vision_handlers, src)
		if(owner.client)
			owner.client.view = world.view

		owner.client.images -= landing_images
	..()

// The eye can see turfs for landing, but is unable to see anything else.
/mob/observer/eye/shuttle/additional_sight_flags()
	return SEE_TURFS|BLIND