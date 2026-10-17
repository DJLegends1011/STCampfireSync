set_xmakever("2.8.2")
set_project("STCampfireSync")
set_version("0.1.0")
set_license("MIT")
set_languages("c++23")
set_warnings("allextra")
set_encodings("utf-8")

add_rules("mode.debug", "mode.release")

-- CommonLibSSE-NG checkout next to this repo. Change the path if yours lives elsewhere.
includes("../CommonLibSSE-NG")

target("STCampfireSync")
    add_deps("commonlibsse-ng")
    add_rules("commonlibsse-ng.plugin", {
        name = "STCampfireSync",
        author = "DJLegends",
        description = "Campfire sync example for the Skyrim Together Plugin API",
        options = { address_library = true }
    })
    add_files("src/*.cpp")
    add_includedirs("include")
    add_cxxflags("cl::/wd4100", "cl::/wd4200", "cl::/wd4201") -- unused callback parameters, and CommonLib header noise
target_end()
