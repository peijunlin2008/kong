"""A module defining the third party dependency luarocks"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//build/luarocks/lua:lua_repositories.bzl", "lua_repositories")
load("@kong_bindings//:variables.bzl", "KONG_VAR")

def luarocks_repositories():
    lua_repositories()

    version = KONG_VAR["LUAROCKS"]

    http_archive(
        name = "luarocks",
        build_file = "//build/luarocks:BUILD.luarocks.bazel",
        strip_prefix = "luarocks-" + version,
        sha256 = KONG_VAR["LUAROCKS_SHA256"],
        urls = [
            "https://luarocks.github.io/luarocks/releases/luarocks-" + version + ".tar.gz",
        ],
    )
