setup() {
	load 'test_helper/bats-support/load'
	load 'test_helper/bats-assert/load'

	DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" 1>/dev/null 2>&1 && pwd)"
	PATH="$DIR/../bin:$PATH"
}

@test "prints error when no package name" {
	run link_changelog
	assert_failure "error: missing package name"
}

@test "prints error when no tag" {
	run link_changelog some_package
	assert_failure "error: invalid tag"
}

@test "correctly processes simple version (1)" {
	run link_changelog some_package 1.0.0+1
	assert_output "https://pub.dev/packages/some_package/changelog#1001"
}

@test "correctly processes simple git tag (1)" {
	run link_changelog some_package-v1
	assert_output "https://pub.dev/packages/some_package/changelog#1"
}

@test "correctly processes simple git tag (2)" {
	run link_changelog some_package-v1.0.0
	assert_output "https://pub.dev/packages/some_package/changelog#100"
}

@test "correctly processes simple git tag (3)" {
	run link_changelog some_package-v4.2.0
	assert_output "https://pub.dev/packages/some_package/changelog#420"
}

@test "correctly processes simple git tag (4)" {
	run link_changelog some_package-v4.2.0+1
	assert_output "https://pub.dev/packages/some_package/changelog#4201"
}

@test "correctly processes simple git tag (5)" {
	run link_changelog some_package-v14.22.0+10
	assert_output "https://pub.dev/packages/some_package/changelog#1422010"
}

@test "correctly processes simple git tag (6)" {
	run link_changelog bloc-v8.0.0-dev.5
	assert_output "https://pub.dev/packages/bloc/changelog#800-dev5"
}

@test "correctly processes prefixed git (1)" {
	run link_changelog maestro_cli-v1
	assert_output "https://pub.dev/packages/maestro_cli/changelog#1"
}

@test "correctly processes prefixed git (2)" {
	run link_changelog maestro_cli-v0.4.4
	assert_output "https://pub.dev/packages/maestro_cli/changelog#044"
}

@test "correctly processes prefixed git (3)" {
	run link_changelog maestro_cli-v0.4.4+3
	assert_output "https://pub.dev/packages/maestro_cli/changelog#0443"
}

@test "correctly processes prefixed git (4)" {
	run link_changelog maestro_cli-v1.12.15+32
	assert_output "https://pub.dev/packages/maestro_cli/changelog#1121532"
}

@test "correctly processes package name and simple git tag (1)" {
	run link_changelog some_package v1
	assert_output "https://pub.dev/packages/some_package/changelog#1"
}

@test "correctly processes package name and simple git tag (2)" {
	run link_changelog some_package v1.0.0
	assert_output "https://pub.dev/packages/some_package/changelog#100"
}

@test "correctly processes package name and simple git tag (3)" {
	run link_changelog some_package v4.2.0
	assert_output "https://pub.dev/packages/some_package/changelog#420"
}

@test "correctly processes package name and simple git tag (4)" {
	run link_changelog some_package v4.2.0+1
	assert_output "https://pub.dev/packages/some_package/changelog#4201"
}

@test "correctly processes package name and simple git tag (5)" {
	run link_changelog some_package v14.22.0+10
	assert_output "https://pub.dev/packages/some_package/changelog#1422010"
}

@test "correctly processes package name and prefixed git tag (1)" {
	run link_changelog maestro_cli v1
	assert_output "https://pub.dev/packages/maestro_cli/changelog#1"
}

@test "correctly processes package name and prefixed git tag(2)" {
	run link_changelog maestro_cli v0.4.4
	assert_output "https://pub.dev/packages/maestro_cli/changelog#044"
}

@test "correctly processes package name and prefixed git tag (3)" {
	run link_changelog maestro_cli v0.4.4+3
	assert_output "https://pub.dev/packages/maestro_cli/changelog#0443"
}

@test "correctly processes package name and prefixed git tag (4)" {
	run link_changelog maestro_cli v1.12.15+32
	assert_output "https://pub.dev/packages/maestro_cli/changelog#1121532"
}

@test "correctly processes package name and prefixed git tag (5)" {
	run link_changelog maestro_cli v1.12.15+32-dev.10
	assert_output "https://pub.dev/packages/maestro_cli/changelog#1121532-dev10"
}
