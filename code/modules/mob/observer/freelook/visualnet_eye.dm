// Streams chunks as it moves around, which will show it what the controller can and cannot see.

/mob/observer/eye/visualnet
	var/list/visibleChunks = list()

	var/datum/visualnet/visualnet

/mob/observer/eye/visualnet/Destroy()
	. = ..()
	visualnet = null

/mob/observer/eye/visualnet/possess(var/mob/user)
	..()
	visualnet.update_eye_chunks(src, TRUE)

/mob/observer/eye/visualnet/release(var/mob/user)
	if(owner != user || !user)
		return
	if(owner.eyeobj != src)
		return
	visualnet.remove_eye(src)
	if(owner.client)
		owner.client.eye = owner.client.mob
		owner.client.perspective = MOB_PERSPECTIVE
	LAZYREMOVE(user.additional_vision_handlers, src)
	owner.eyeobj = null
	owner = null
	SetName(initial(name))

// Use this when setting the eye's location.
// It will also stream the chunk that the new loc is in.
/mob/observer/eye/visualnet/setLoc(var/T)
	. = ..()

	if(.)
		visualnet.update_eye_chunks(src)