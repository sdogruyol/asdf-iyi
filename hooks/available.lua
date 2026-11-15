local http = require("http")
local json = require("json")
local iyi = require("iyi")

-- Newest first, as the GitHub releases API returns them. mise reverses the
-- list into its oldest-first order. Only releases with an archive for this
-- platform are listed, so `mise ls-remote` never offers a version that would
-- 404 on this machine.
function PLUGIN:Available(ctx)
    local resp, err = http.get({ url = iyi.api .. "/releases?per_page=100" })
    if err ~= nil then
        error("failed to fetch iyi releases: " .. err)
    end
    if resp.status_code ~= 200 then
        error("GitHub API returned " .. resp.status_code .. ": " .. resp.body)
    end

    local releases = json.decode(resp.body)
    local target, ext = iyi.host_target()
    local result = {}

    for _, release in ipairs(releases) do
        local version = iyi.normalize(release.tag_name)
        if version ~= nil and not release.draft and not release.prerelease then
            local filename = "iyi-" .. version .. "-" .. target .. "." .. ext
            if iyi.find_asset(release, filename) ~= nil then
                table.insert(result, {
                    version = version,
                    created_at = release.published_at,
                })
            end
        end
    end

    if #result == 0 then
        error("no iyi releases found for " .. target)
    end
    return result
end
