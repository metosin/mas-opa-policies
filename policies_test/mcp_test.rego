package mcp.tool_invocation_test

import data.mcp.tool_invocation

test_allow_normal_tool if {
	tool_invocation.allow with input as {"user": "alice", "teams": ["default"], "tool_name": "search-vectors"}
}

test_deny_unauthenticated if {
	not tool_invocation.allow with input as {"user": "", "teams": [], "tool_name": "search-vectors"}
}

test_deny_restricted_tool_non_admin if {
	not tool_invocation.allow with input as {"user": "alice", "teams": ["default"], "tool_name": "delete-vectors"}
}

test_allow_restricted_tool_admin if {
	tool_invocation.allow with input as {"user": "admin", "teams": ["admin"], "tool_name": "delete-vectors"}
}

test_deny_restricted_tool_admin_reset_non_admin if {
	not tool_invocation.allow with input as {"user": "alice", "teams": ["default"], "tool_name": "admin-reset"}
}

test_allow_restricted_tool_admin_reset_admin if {
	tool_invocation.allow with input as {"user": "admin", "teams": ["admin"], "tool_name": "admin-reset"}
}
