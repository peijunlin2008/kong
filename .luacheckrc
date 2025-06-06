std             = "ngx_lua"
unused_args     = false
redefined       = false
max_line_length = false


globals = {
    "_KONG",
    "kong",
    "ngx.IS_CLI",
}


not_globals = {
    "string.len",
    "table.getn",
}


ignore = {
    "6.", -- ignore whitespace warnings
}


exclude_files = {
    "spec/fixtures/invalid-module.lua",
    "spec-old-api/fixtures/invalid-module.lua",
    "bazel-bin",
    "bazel-out",
    "bazel-kong",
}

files["kong/tools/sandbox/kong.lua"] = {
     read_globals = {
        "_ENV",
        "table.pack",
        "table.unpack",
     }
}


files["kong/hooks.lua"] = {
    read_globals = {
        "table.pack",
        "table.unpack",
    }
}


files["kong/db/schema/entities/workspaces.lua"] = {
    read_globals = {
        "table.unpack",
    }
}


files["kong/plugins/ldap-auth/*.lua"] = {
    read_globals = {
        "bit.mod",
        "string.pack",
        "string.unpack",
    },
}


files["spec/**/*.lua"] = {
    std = "ngx_lua+busted",
}

files["**/*_test.lua"] = {
    std = "ngx_lua+busted",
}

files["spec-old-api/**/*.lua"] = {
    std = "ngx_lua+busted",
}
