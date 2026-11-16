extends RefCounted
## A single deterministic floor plan, not a room generator. Units are metres.
const BUILDING_ID := "building_01"
const FLOOR_ID := "building_01_f05"
const SPAWN := Vector3(-3.95,0.02,0.02)
const CORRIDOR := Rect2(-6.35,-1.95,1.75,10.50)
const ROOMS := {
	"501":Rect2(-4.60,-2.10,9.20,4.20),
	"502":Rect2(-15.55,-2.10,9.20,4.20),
	"503":Rect2(-4.60,2.25,9.20,4.20),
	"504":Rect2(-15.55,2.25,9.20,4.20)}
const PORTALS := {
	"501":Vector3(-4.525,1.0,1.11),
	"502":Vector3(-6.425,1.0,1.11),
	"503":Vector3(-4.525,1.0,5.46),
	"504":Vector3(-6.425,1.0,5.46),
	"stairs":Vector3(-5.475,1.0,8.625)}
const STAIR_RESERVE := Rect2(-7.10,8.70,3.25,4.0)

static func room_id(number: String) -> String:
	return FLOOR_ID+"_"+number

static func door_id(number: String) -> String:
	return room_id(number)+"_door"
