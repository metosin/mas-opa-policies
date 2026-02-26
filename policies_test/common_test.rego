package common_test

import data.common

test_is_authenticated if {
	common.is_authenticated with input as {"user": "alice"}
}

test_not_authenticated_empty if {
	not common.is_authenticated with input as {"user": ""}
}

test_not_authenticated_missing if {
	not common.is_authenticated with input as {}
}

test_is_team_member if {
	common.is_team_member("admin") with input as {"teams": ["admin", "default"]}
}

test_not_team_member if {
	not common.is_team_member("admin") with input as {"teams": ["default"]}
}
