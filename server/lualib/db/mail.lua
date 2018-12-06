local mail = {}
local connection_handler
-- local mongodb

local function make_key (account)
	return connection_handler (account)
end

function mail.init (ch)
    connection_handler = ch
	-- mongodb = mg
end

function mail.check_role_exist( account )
	local mongodb = make_key(account)
    local ret = mongodb.RoleInfo:find({ID = account})
	if ret and ret:hasNext() then
		return true
	end
end

function mail.save_mail( account , mail_info )
	local mongodb = make_key(account)
    return mongodb.Mails:safe_update({ID = account},{["$push"] = {MailList = mail_info}})    
end

function mail.update_mail( account , mail_info )
	local mongodb = make_key(account)
    return mongodb.Mails:safe_update({ID = account,['MailList.mail_guid'] = mail_info.mail_guid},{["$set"] = {['MailList.$'] = mail_info}})    
end

function mail.del_mail( account , mail_guid )
	local mongodb = make_key(account)
	return mongodb.Mails:safe_update({ID = account},{["$pull"] = {MailList= {mail_guid = mail_guid}}})   
end

function mail.del_all_mail( account )
	local mongodb = make_key(account)
	return mongodb.Mails:safe_update({ID = account},{["$pull"] = {MailList= {}}})   
end

return mail
