package acp.authz

default allow = false

tid = input.authn_ctx.tid

allow {
  input.request.method == "GET"
  id := input.scopes["dashboard.read.*"][_].params[0]
    input.request.path ==  sprintf("/%v/dashboard/%v",[input.authn_ctx.tid,id] )
  
}

allow {
  input.request.method == "GET"
  input.scopes["dashboard.read.*"][_].params[0] == "all"
  
}