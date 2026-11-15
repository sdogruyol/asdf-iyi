local http = require("http")
local iyi = require("iyi")

-- The oldest release with an archive for this platform is filtered out here,
-- so `mise ls-remote` never offers a version that would 404 on this machine.
-- The ref advertisement is newest-last, so sort explicitly.
function PLUGIN:Available(ctx)
    local resp, err = http.get({ url = iyi.refs })
    if err ~= nil then
        error("failed to fetch iyi tags: " .. err)
    end
    if resp.status_code ~= 200 then
        error("fetching iyi tags failed: HTTP " .. resp.status_code)
    end

    local target = iyi.host_target()
    local result, seen = {}, {}

    for tag in resp.body:gmatch("refs/tags/(v?%d+%.%d+%.%d+)") do
        local version = iyi.normalize(tag)
        if version ~= nil and seen[version] == nil and iyi.supports(version, target) then
            seen[version] = true
            table.insert(result, { version = version })
        end
    end

    if #result == 0 then
        error("no iyi releases found for " .. target)
    end

    -- Available returns newest first; mise reverses it into its own order.
    table.sort(result, function(a, b)
        return iyi.version_lt(b.version, a.version)
    end)
    return result
end
