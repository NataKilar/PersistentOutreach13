/mob/observer/eye/shuttle
	name = "Shuttle Docking Eye"
	desc = "A visual projection used to assist in the docking of a shuttle."

/mob/observer/eye/shuttle/New(var/loc, var/net)
	..()
	visualnet = net

/mob/observer/eye/possess(var/mob/user)
	..()
	if(owner) LAZYDISTINCTADD(owner.additional_vision_handlers, src)

/mob/observer/eye/release(var/mob/user)
	if(owner) LAZYREMOVE(user.additional_vision_handlers, src)
	..()

// The eye can see turfs for landing, but is unable to see anything else.
/mob/observer/eye/shuttle/additional_sight_flags()
	return SEE_TURFS|BLIND