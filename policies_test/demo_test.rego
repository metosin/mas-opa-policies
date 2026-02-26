package demo.request_validation_test

import data.demo.request_validation

test_allow_small_request if {
	request_validation.allow with input as {"user": "alice", "content_length": 1024}
}

test_allow_at_limit if {
	request_validation.allow with input as {"user": "alice", "content_length": 102400}
}

test_deny_over_limit if {
	not request_validation.allow with input as {"user": "alice", "content_length": 102401}
}

test_deny_unauthenticated if {
	not request_validation.allow with input as {"user": "", "content_length": 100}
}
