package common

default allow := false

is_authenticated {
	input.user != ""
}

is_team_member(team) {
	input.teams[_] == team
}
