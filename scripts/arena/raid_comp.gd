class_name RaidComp
extends Object

## Lobby role is raid composition only. Spec slots stay independent.

const ROLE_TANK := "tank"
const ROLE_HEALER := "healer"
const ROLE_DPS := "dps"

const MEMBER_BULWARK := "bulwark"
const MEMBER_MEND := "mend"
const MEMBER_HEX := "hex"
const MEMBER_VEX := "vex"
const MEMBER_ROOK := "rook"

const POS_TANK := Vector3(-4.2, 0.1, 15.2)
const POS_HEAL := Vector3(4.2, 0.1, 15.2)
const POS_HEX := Vector3(-7.2, 0.1, 13.6)
const POS_VEX := Vector3(7.2, 0.1, 13.6)


static func normalize_role(role: String) -> String:
	match role.strip_edges().to_lower():
		ROLE_TANK, ROLE_HEALER:
			return role.strip_edges().to_lower()
		_:
			return ROLE_DPS


static func ai_members(player_role: String) -> PackedStringArray:
	match normalize_role(player_role):
		ROLE_TANK:
			return PackedStringArray([MEMBER_MEND, MEMBER_HEX, MEMBER_VEX, MEMBER_ROOK])
		ROLE_HEALER:
			return PackedStringArray([MEMBER_BULWARK, MEMBER_HEX, MEMBER_VEX, MEMBER_ROOK])
		_:
			return PackedStringArray([MEMBER_BULWARK, MEMBER_MEND, MEMBER_HEX, MEMBER_VEX])


static func member_position(member_id: String, player_role: String) -> Vector3:
	match member_id:
		MEMBER_BULWARK:
			return POS_TANK
		MEMBER_MEND:
			return POS_HEAL
		MEMBER_HEX:
			return POS_HEX
		MEMBER_VEX:
			return POS_VEX
		MEMBER_ROOK:
			return POS_TANK if normalize_role(player_role) == ROLE_TANK else POS_HEAL
		_:
			return POS_HEX
