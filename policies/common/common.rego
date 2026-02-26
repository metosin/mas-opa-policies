package common

default allow := false

is_authenticated if {
	input.user != ""
}

is_team_member(team) if {
	input.teams[_] == team
}
