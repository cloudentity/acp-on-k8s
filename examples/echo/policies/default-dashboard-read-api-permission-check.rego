package acp.authz

default allow = false


permissions = {
        "user": ["123","124"], 
        "user1": ["125","126"], 
        "user2": ["127"] 
        }[input.authn_ctx.sub]


allow {

  input.authn_ctx.idp != ""
  input.authn_ctx.sub != "admin"
  # User was graned explicit accss to the Dashboard

  id := permissions[_]
  input.request.path ==  sprintf("/%v/dashboard/%v",[input.authn_ctx.tid,id] )
  
}


allow {
  
  # User is an admin user
  input.authn_ctx.idp != ""
  input.authn_ctx.sub == "admin"
  
}

allow {
  
  # CC flow
  input.authn_ctx.idp == ""
  
}

