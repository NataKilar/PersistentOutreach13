GLOBAL_DATUM_INIT(exonets, /repository/exonet, new)

/repository/exonet
	var/list/registered_exonets

/repository/exonet/New()
	registered_exonets = list()

/repository/exonet/proc/get_exonet_by_area(var/area/A)
	for(var/datum/exonet/exonet in registered_exonets)
		if(A in exonet.areas)
			return exonet

/repository/exonet/proc/register_exonet(var/datum/exonet/e)
	registered_exonets += e

/repository/exonet/proc/unregister_exonet(var/datum/exonet/e)
	registered_exonets -= e

/repository/exonet/proc/create_email(var/mob/M, var/name, var/domain, var/rank)