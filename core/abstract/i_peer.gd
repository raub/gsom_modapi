extends IGsomInstigator
class_name IGsomPeer

## Base peer - representation of network/lobby client.
##
## This is what **Core implements**.
## I.e. opposed to IGsomEntity implementations, shipped by mods.
##
## Peers are generated and managed by the network service.
## This class reflects the publicly available part of a network peer.
## All peers are instigators - no need to register them manually.
##
## The host may recognize previously connected peers by `_get_identity`.
## The network implementation can preserve identity past disconnection and crash events.
##
## Note, guideline keywords:
## - [readonly] - if you mutate it, you will face a terrible fate.
## - [core] - it is safe to assume the Core has implemented it.
## - [server] - calling it from non-host will have no effect.

## [core] A volatile internal ID used for network routing.
##
## Some UI and debugging may still want the ephemeral numeric ID.
## This is the proper way to obtain it from the network implementation.
func _get_id() -> int:
	assert(false, "Not implemented")
	return IGsomNetwork.NET_ID_EMPTY

## [core] Is this peer online?
##
## All peers start as valid and connected - that's how they get here.
## But they can become temporarily disconnected, and reconnect.
func _get_connected() -> bool:
	assert(false, "Not implemented")
	return false

## Is this the local peer?
##
## Each instance only has one "local" peer.
## Assume this check is always valid, because all injections are made early.
func check_is_local() -> bool:
	return _get_identity() == net.get_local_identity()

## Is this the host peer?
##
## Each server only has one "host" peer at most.
## Assume this check is always valid, because all injections are made early.
func check_is_host() -> bool:
	return _get_identity() == net.get_host_identity()
