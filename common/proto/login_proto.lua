local sparser = require "sprotoparser"

local login_proto = {}

login_proto.c2s = sparser.parse [[
.package {
	type 0 : integer
	session 1 : integer
}

handshake 1 {
	request {
		account 0 : string			# username        
		client_pub 1 : string		# srp argument, client public key, known as 'A'
	}
	response {
		user_exists 0 : boolean		# 'true' if username is already used
		salt 1 : string		# srp argument, salt, known as 's'
		server_pub 2 : string		# srp argument, server public key, known as 'B'
		challenge 3 : string		# session challenge
	}
}

auth 2 {
	request {
		challenge 0 : string		# encrypted challenge
		password 1 : string		# encrypted password. send this ONLY IF you're registrying new account
	}
	response {
		session 0 : integer		# login session id, needed for further use
		expire 1 : integer		# session expire time, in second
		challenge 2 : string		# token request challenge
	}
}

challenge 3 {
	request {
		session 0 : integer		# login session id
		challenge 1 : string		# encryped challenge
	}
	response {
		token 0 : string		# login token
		challenge 1 : string		# next token challenge
        ip 2 : string   # gameserver ip
        port 3 : integer   # gameserver port
	}
}

login 4 {
	request {
		session 0 : integer		# login session id
		token 1 : string		# encryped token
	}
}

logintest 5 {
	request {
		account 0 : string
		password 1 : string
	}
	response {
		session 0 : integer		# login session id
		token 1 : string		# encryped token
 	       	ip 2 : string   # gameserver ip
        	port 3 : integer   # gameserver port
	}
}

login_user_center 6 {
	request {
		deviceId 0 : string
		unionId 1 : integer
		siteId 2 : integer
		terminalSource 3 : integer
		version 4 : string
		access_token 5 : string
	}
	response {
		session 0 : integer		# login session id
		token 1 : string		# encryped token
        ip 2 : string   # gameserver ip
        port 3 : integer   # gameserver port
	}
}

]]

login_proto.s2c = sparser.parse [[
.package {
	type 0 : integer
	session 1 : integer
}
]]

return login_proto
