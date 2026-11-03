# SPDX-License-Identifier: Apache-2.0
# Existing target entries keep their last effective mode unless bulk=1.
BEGIN {
    package_re = "^[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)+$"
    suffix = mode == "generate" ? "!" : mode == "hack" ? "?" : ""
}
FILENAME == ARGV[1] {
    line = $0
    sub(/\r$/, "", line)
    lines[++line_count] = line
    clean = line
    sub(/#.*/, "", clean)
    gsub(/^[ \t]+|[ \t]+$/, "", clean)
    sub(/[!?]$/, "", clean)
    gsub(/^[ \t]+|[ \t]+$/, "", clean)
    if (clean ~ package_re) {
        keys[line_count] = clean
        last[clean] = line_count
        seen[clean] = 1
    }
    next
}
{
    package = $1
    if (package ~ package_re) {
        valid_packages++
        if (!installed[package]++) packages[++package_count] = package
    }
}
END {
    if (!valid_packages) exit 2
    for (i = 1; i <= line_count; i++) {
        package = keys[i]
        if (!package) {
            print lines[i]
        } else if (last[package] == i) {
            if (bulk) {
                comment = index(lines[i], "#")
                print package suffix (comment ? " " substr(lines[i], comment) : "")
            } else {
                print lines[i]
            }
        }
    }
    for (i = 1; i <= package_count; i++) {
        package = packages[i]
        if (!seen[package]++) print package suffix
    }
}
