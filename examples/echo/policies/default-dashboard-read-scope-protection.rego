package acp.authz

default allow = false
user_permissions = {
        "user": ["123","124"], 
        "user1": ["125","126"], 
        "user2": ["127"] 
        }

allow {

  input.authn_ctx.sub != "admin"
  # User was graned explicit accss to the Dashboard
  
  scope := input.scopes["dashboard.read.*"][_]
    user_permissions[input.authn_ctx.sub][_] ==  scope.params[0]
  
}


allow {
  
  # User is an admin user
  input.authn_ctx.sub == "admin"

}