
local friend = {}
local connection_handler


local function make_key (account)
    return connection_handler (account)
end

function friend.init (ch)
	connection_handler = ch
end

----------------------------------chat

function friend.saveFriendOfflineMessage( chat_info )
    local mongodb = make_key(chat_info.role_id)
    return mongodb.FriendOfflineMessage:safe_update({ID = chat_info.target_id},{["$push"] = {OfflineMessages = chat_info}})
end

function friend.delFriendOfflineMessage( account )
    local mongodb = make_key(account)
    return mongodb.FriendOfflineMessage:safe_update({ID = account},{["$pull"] = {OfflineMessages = {}}})
end

-----------------------------------friend

function friend.saveFriend( account , friend_info )
    local mongodb = make_key(account)
    return mongodb.Friends:safe_update({ID = account},{["$push"] = {FriendList = friend_info}})    
end

function friend.delFriend( account , friend_id )
    local mongodb = make_key(account)
	return mongodb.Friends:safe_update({ID = account},{["$pull"] = { FriendList = { ['role_info.role_id'] = friend_id } }})   
end

function friend.updateFriend( account, friend_info )
    local mongodb = make_key(account)
    local ret = mongodb.Friends:safe_update({ID = account,['FriendList.role_info.role_id'] = friend_info.role_info.role_id},{["$set"] = {['FriendList.$'] = friend_info}},true)
    if not ret then
        return mongodb.Friends:safe_update({ID = account},{["$push"] = {FriendList = friend_info}})
    end
    return ret
end

---------------------------------give_item


function friend.saveGiveInfo( account , give_info )
    local mongodb = make_key(account)
    return mongodb.OfflineGiveInfo:safe_update({ID = account},{["$push"] = {OfflineGiveInfo = give_info}},true)
end

function friend.delOfflineGiveInfo( account )
    local mongodb = make_key(account)
    return mongodb.OfflineGiveInfo:safe_update({ID = account},{["$pull"] = {OfflineGiveInfo = {}}})
end

--[[
-- 返回 redis实例 和 user map的key
local function make_key (name)
	return connection_handler (name), string.format ("user:%s", name)
end

local UserList = "UserList"
local function make_list_key ()
    return connection_handler (UserList), string.format ("%s", UserList)
end

local function make_friend_key (account)
    return connection_handler (account), string.format ("user:%d", account)
end

local function make_accInfo_key (account)
    return connection_handler (account), string.format ("user:%s_%d", "info", account)
end

local function make_friend_key (account)
    return connection_handler (account), string.format ("user:%s_%d", "friends", account)
end

function friend.delFreind( account, friend )
    local connection, key = make_friend_key (account)
    assert (connection:hdel (key, friend) ~= 0, "delFreind failed")
    return true
end

function friend.loadFreind( account, friend )
    local connection, key = make_friend_key (account)
    return connection:hget (key, friend)
end

function friend.loadFriendList( account )
    local connection, key = make_friend_key (account)
    return connection:hvals (key) or {}
end
]]
return friend
