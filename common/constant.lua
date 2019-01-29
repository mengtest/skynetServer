
local constant = {

TravelerAccount = "666666",
default_password = "111111",


RNDK_LIMIT_COUNT = 100,  --排行榜总人数
RANK_ITEM_ID = 100001, --道具排行榜道具id
ITEMGIFT = 5,
MONTH_CARD_DAY_COUNT = 30,

----------------------------------------------------------------------

FlagOffline = 0,
FlagOnline = 1,

---------------friend---------
FlagNone = 0,
FlagOK = 1,  --加好友成功
FlagApplying = 2, --申请添加
FlagBeApply = 3, --被添加
FlagAccept = 4, --同意
FlagBeAccept = 5, --被同意 
FlagReject = 6, --拒绝添加
FlagBeReject = 7, --被拒绝


-------------chat_type--------
System = 1,--系统聊天
World = 2,--世界聊天
Local = 3,--本地聊天
Guild = 4,--公会聊天
Team = 5,--队伍聊天
Transaction = 6,--交易聊天
Private = 7, --私聊

-------------mail_type--------
System = 1,--系统
Player = 2,--player

-------------mail_status--------
AlreadySend = 1, --已经发送
Undisposed = 2,  --未处理
AlreadyRead = 3, --已经查看
AlreadyGet = 4, --已经领取
Expire = 5, --超时

-------------rank_type------------
RankNimbus = 1,
RankRune = 2,  
RankKill = 3,  --黄金怪击杀排行榜
RankNimbusBottle = 4,  --道具排行榜
-- RankLevel = 5,


-------------error_id-------------
ROLE_NOT_EXIST = 1001, --玩家不存在
ROLE_NOT_ONLINE = 1002, --玩家不在线
ITEM_AT_CD = 1003, 

-------------record_type----------


}


return constant
