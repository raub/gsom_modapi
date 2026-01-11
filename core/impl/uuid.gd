class_name GsomUuid

static var __s_uuid_rng: RandomNumberGenerator = null

## Provides for a somewhat-unique identity (e.g. for default `peer.identity`)
##
## Example: "1767603574.422-1450022-813288388"
static func s_uuid() -> StringName:
	if !__s_uuid_rng:
		__s_uuid_rng = RandomNumberGenerator.new()
		__s_uuid_rng.randomize()
	var u: StringName = "%s-%s-%s" % [
		Time.get_unix_time_from_system(), Time.get_ticks_usec(), __s_uuid_rng.randi()
	]
	return u
