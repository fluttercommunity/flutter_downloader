setup() {
	load 'test_helper/bats-support/load'
	load 'test_helper/bats-assert/load'

	DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" 1>/dev/null 2>&1 && pwd)"
	PATH="$DIR/../bin:$PATH"
}

@test "prints error when no tag" {
	run is_prerelease "$package_name"
	assert_failure "error: missing tag"
}

@test "correctly processes package name and git tag (1)" {
	run is_prerelease some_package v1
	assert_output false
}

@test "correctly processes package name and git tag (2)" {
	run is_prerelease some_package v10
	assert_output false
}

@test "correctly processes package name and git tag (3)" {
	run is_prerelease some_package v1.0
	assert_output false
}

@test "correctly processes package name and git tag (4)" {
	run is_prerelease some_package v1.0.0+17
	assert_output false
}

@test "correctly processes package name and git tag (5)" {
	run is_prerelease some_package v0.1
	assert_output true
}

@test "correctly processes package name and git tag (6)" {
	run is_prerelease some_package v0.7.5
	assert_output true
}

@test "correctly processes package name and git tag (7)" {
	run is_prerelease comms comms-v0.0.5
	assert_output true
}

@test "correctly processes package name and version (1)" {
	run is_prerelease some_package 0.7.5
	assert_output true
}

@test "correctly processes package name and version (2)" {
	run is_prerelease some_package 1.0.0
	assert_output false
}

@test "correctly processes package name and version with prefix (2)" {
	run is_prerelease flutter_comms flutter_comms-v0.1
	assert_output true
}

@test "correctly processes package name and version with prefix (3)" {
	run is_prerelease flutter_comms flutter_comms-v1.0.0
	assert_output false
}

@test "correctly processes package name and version with prefix (4)" {
	run is_prerelease flutter_comms flutter_comms-v1.1.0-beta.2
	assert_output true
}

@test "correctly processes version" {
	run is_prerelease flutter_comms-v1.0.0
	assert_output false
}

@test "correctly processes version (2)" {
	run is_prerelease some_package-v10
	assert_output false
}

@test "correctly processes version (3)" {
	run is_prerelease some_package-v1.0
	assert_output false
}

@test "correctly processes version (4)" {
	run is_prerelease some_package-v1.0.0+17
	assert_output false
}

@test "correctly processes version (5)" {
	run is_prerelease some_package-v0.1
	assert_output true
}

@test "correctly processes version (6)" {
	run is_prerelease some_package-v0.7.5
	assert_output true
}

@test "correctly processes version with suffix (1)" {
	run is_prerelease comms-v0.0.5-dev.1
	assert_output true
}

@test "correctly processes version with suffix (2)" {
	run is_prerelease flutter_comms-v0.1-beta.10
	assert_output true
}

@test "correctly processes version with suffix (3)" {
	run is_prerelease flutter_comms-v1.1.2-beta.10
	assert_output true
}
