package mcp.tool_invocation

import data.common

default allow := false

# Allow if user is authenticated and tool is not restricted
allow if {
	common.is_authenticated
	not is_restricted_tool
}

# Restricted tools require admin team membership
allow if {
	common.is_authenticated
	is_restricted_tool
	common.is_team_member("admin")
}

is_restricted_tool if {
	restricted_tools := {"delete-vectors", "admin-reset"}
	restricted_tools[input.tool_name]
}
