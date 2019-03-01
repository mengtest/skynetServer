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

.moudle_base {
	grade 0 : integer
 	term 1 : integer
 	unit 2 : integer
 	moudleId 3 : integer(1)
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
	unit 3 : integer
	uText 4 : string
	moudle 5 : *integer(1)
}

.table14Info {
	image 0 : string
	content 1 : string
	voice 3 : string
}	

.table10Info{
	word 0 : string
	cword 1 : string
	icon1 2 : string
	icon2 3 : string
	voice 4 : string
}		

.table11Info{
	option 0 : *string
	right 1 : string
	tips 2 : string
	clues1 3 : *string
	cluesVoice1 4 : *string
	rightText1 5 : string
	rightVoice1 6 : string
	rightIcon1 7 : string
	clues2 8 : *string
	cluesVoice2 9 : *string
	rightText2 10 : string
	rightVoice2 11 : string
	rightIcon2 12 : string
	clues3 13 : *string
	cluesVoice3 14 : *string
	rightText3 15 : string
	rightVoice3 16 : string
	rightIcon3 17 : string
}	

.table12Info{
	headTable 0 : string
	headId 1 : integer
	text 2 : string
	voice 3 : string
	deleUserId 4 : integer
	confuse 5 : *string
	confuseVoice 6 : *string
}

.table13Info{
	id 0 : integer
	text 1 : string
	chaosText 2 : *string
	tips 3 : string
}

.table4Info{
	id 0 : integer
	cStatements 1 : *string
	statements 2 : *string
	headline 3 : string
	userIconStep 4 : *string
	sVoice 5 : *string
	headIds 6 : *integer
	contentInfo 7 : *table12Info
}

]]

local c2s = [[
GetLearnInfo 20 {
	response {
		sure 0 : boolean
	}
}

GetGradeInfo 21 {
	request {
		grade 0 : integer
		term 1 : integer
	}
	response {
		grade 0 : integer
		term 1 : integer
		isPay 2 : boolean
		info 3 : *gradeInfo
	}
}

GetMoudleInfo 22 {
	request {
		grade 0 : integer
	 	term 1 : integer
	 	unit 2 : integer
	 	moudleId 3 : integer(1)
	}
	response {
		status 0 : boolean
	}
}

SendLearnResultInfo 23 {
	request {
		moudleBase 0 : moudle_base
		order 1 : integer
		score 2 : integer
	}
	response {
		status 0 : boolean
	}
}

GetResultInfo 24 {
	request {
		moudleBase 0 : moudle_base
	}
	response {
		moudleBase 0 : moudle_base
		order 1 : integer
		score 2 : *integer
	}
}

PayCourse 25 {
	request {
		grade 0 : integer
	 	term 1 : integer
	}
	response {
		status 0 : boolean
	}
}

heartbeat 200 {}


]]

local s2c = [[

client_user_info 20 {
	request {
		ID 0 : integer
		NickName 1 : string
		IsTraveler 2 : boolean
		Sex 3 : integer
	}
}

SyncMoudle1Info 21 {
	request {
		id 0 : integer
		statement 1 : string
		cStatement 2 : string
		voice 3 : string
		contentInfo 4 : *table14Info
		moudleBase 5 : moudle_base
	}
}

SyncMoudle2Info 22 {
	request {
		id 0 : integer
		cStatements 1 : *string
		statements 2 : *string
		voices 3 : *string
		contentInfo 4 : *table10Info
		moudleBase 5 : moudle_base
	}
}

SyncMoudle3Info 23 {
	request {
		id 0 : integer
		cStatements 1 : *string
		statements 2 : *string
		voices 3 : *string
		steps 4 : *string
		contentInfo 5 : *table11Info
		moudleBase 6 : moudle_base
	}
}

SyncMoudle4Info 24 {
	request {
		infoList 0: *table4Info
		moudleBase 1 : moudle_base
	}
}

SyncMoudle5Info 25 {
	request {
		id 0 : integer
		unpackVoice 1 : *string
		sVoice 2 : *string
		soundmark 3 : *string
		wordUnpack 4 : *string
		contentInfo 5 : *table10Info
		moudleBase 6 : moudle_base
	}
}

SyncMoudle6Info 26 {
	request {
		id 0 : integer
		cStatements	1 : *string
		scene2st 2 : *string
		scene1 3 : string
		scene2sb 4 : *string
		cluesVoice1	5 : *string
		scene1sb 6 : *string
		clues2 7 : *string
		scene1text 8 : *string
		statements 9 : *string 
		scene2 10 : string
		cluesVoice2	11 : *string
		scene1voice	12 : *string
		title 13 : string
		clues1 14 : *string
		sVoice 15 : *string
		scene1st 16 : *string
		scene2voice 17 : *string
		scene2text 18 : *string
		moudleBase 19 : moudle_base	
	}
}

SyncMoudle7Info 27 {
	request {
		id 0 : integer
		cStatements	1 : *string
		statements 2 : *string
		wordVoice 3 : string
		expandIcon 4 : *string
		voice 5 : *string
		expandVoice 6 : *string
		icon 7 : string
		expandWord 8 : *string
		moudleBase 9 : moudle_base
	}
}

SyncMoudle8Info 28 {
	request {
		id 0 : integer
		cStatements 1 : *string
		statements 2 : *string 
		voice 3 : *string
		weight 4 : *string
		contentInfo1 5 : *table10Info
		contentInfo2 6 : *table13Info
		moudleBase 7 : moudle_base	
	}
}
sync_shop_config 201 {
	request {
		shop_config 0 : *shop_config
	}
}

]]

game_proto.types = sparser.parse (types)
game_proto.c2s = sparser.parse (types .. c2s)
game_proto.s2c = sparser.parse (types .. s2c)

return game_proto
