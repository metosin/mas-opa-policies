package common_test

import data.common

test_is_authenticated {
	common.is_authenticated with input as {"user": "alice"}
}

test_not_authenticated_empty {
	not common.is_authenticated with input as {"user": ""}
}

test_not_authenticated_missing {
	not common.is_authenticated with input as {}
}

test_is_team_member {
	common.is_team_member("admin") with input as {"teams": ["admin", "default"]}
}

test_not_team_member {
	not common.is_team_member("admin") with input as {"teams": ["default"]}
}
