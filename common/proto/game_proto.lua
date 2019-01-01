local sparser = require "sprotoparser"

local game_proto = {}

local types = [[

.package {
	type 0 : integer
	session 1 : integer
}

.attribute {
	level 0 : integer
	exp 1 : integer
	ce 2 : integer
	hp 3 : integer
	hp_max 4 : integer
	atk 5 : integer
	def 6 : integer
	mspd 7 : integer
	aspd 8 : integer
	cri 9 : integer
	avo 10 : integer
	resilence 11 : integer
	recovery 12 : integer
}
.role_info {
	role_id 0 : integer
	nickname 1 : string
	race 2 : integer
	level 3 : integer
}

.item_info {
	item_id 0 : integer
	num 1 : integer
}

.mail_info {
	role_info 0 : role_info
	title 1 : string
	content 2 : string
	item_list 3 : *item_info
	time 4 : integer
	status 5 : integer
	type 6 : integer
	mail_id 7 : integer
	mail_guid 8 : string
	target_id 9 : integer
	target_name 10 : string
}

.shop_info {
	shop_id 0 : integer
}

.item_config {
	ItemId 0 : integer
 	Name 1 : string
	Describe 2 : string
 	CanAttr 3 : integer
 	ItemType 4 : integer
	UseInterval 5 : integer
	AddHp 6 : integer
	AddAtkSpeedTime 7 : integer
	LockTime 8 : integer
	ShadowTime 9 : integer
	Item 10 : *item_info
	Alias 11 : string
	AddRune 12 : integer
	AddNimbus 13 : integer
	AddExp 14 : integer
} 

.shop_config {
	ProductId 0 : integer
	Name 1 : string
	Describe 2 : string
	ItemIds 3 : *item_info
	CostNimbus 4 : integer
	CostRune 5 : integer
	Count 6 : integer
	VipDiscount 7 : integer
	NeedVipLevel 8 : integer
	Type 9 : integer
}

.gradeInfo {
	id 0 : integer
	grade 1 : integer
	term 2 : integer
	unit 3 : integer
	uText 4 : string
}

]]

local c2s = [[
GetLearnInfo 20 {
	response {
		sure 0 : boolean
	}
}

heartbeat 21 {}


]]

local s2c = [[

client_user_info 20 {
	request {
		ID 0 : integer
		NickName 1 : string
	}
}

sync_grade_info 21 {
	request {
		info 0 : *gradeInfo
	}
}

sync_shop_config 201 {
	request {
		shop_config 1 : *shop_config
	}
}

]]

game_proto.types = sparser.parse (types)
game_proto.c2s = sparser.parse (types .. c2s)
game_proto.s2c = sparser.parse (types .. s2c)

return game_proto
