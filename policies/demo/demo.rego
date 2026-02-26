package demo.request_validation

import data.common

default allow := false

# Allow requests under size limit from authenticated users
allow if {
	common.is_authenticated
	input.content_length <= 102400
}
