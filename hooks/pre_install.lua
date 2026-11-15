local http = require("http")
local iyi = require("iyi")
local log = require("log")

function PLUGIN:PreInstall(ctx)
    local version = iyi.normalize(ctx.version)
    if version == nil then
        error("not an iyi release version: " .. tostring(ctx.version))
    end

    -- `mise lock` calls PreInstall for platforms other than the host. iyi has
    -- no release for some of them (Linux arm64/musl, macOS x86_64, Windows
    -- arm64); return no download there so the lockfile records no artifact.
    local target, ext = iyi.target()
    if target == nil then
        log.debug("iyi has no release for " .. tostring(RUNTIME.osType) .. "-" .. tostring(RUNTIME.archType))
        return { version = version }
    end

    if not iyi.supports(version, target) then
        error("iyi " .. version .. " has no release for " .. target)
    end

    local filename = "iyi-" .. version .. "-" .. target .. "." .. ext
    local dir = iyi.downloads .. "/v" .. version

    -- Releases from 0.12.0 on publish SHA256SUMS. A file line missing for this
    -- platform means the release has no archive for it; a checksum that does
    -- arrive is returned to mise, which verifies the download.
    local sha256 = nil
    local sums, sums_err = http.get({ url = dir .. "/SHA256SUMS" })
    if sums_err ~= nil then
        error("failed to fetch SHA256SUMS for iyi " .. version .. ": " .. sums_err)
    end
    if sums.status_code == 200 then
        sha256 = iyi.find_checksum(sums.body, filename)
        if sha256 == nil then
            error("iyi " .. version .. " has no " .. filename .. " for " .. target)
        end
    elseif sums.status_code == 404 and iyi.version_lt(version, "0.12.0") then
        log.warn("iyi " .. version .. " publishes no SHA256SUMS; the download is not verified")
    else
        error("could not fetch " .. dir .. "/SHA256SUMS (HTTP " .. sums.status_code .. "): iyi " .. version .. " may not be published")
    end

    return {
        version = version,
        url = dir .. "/" .. filename,
        sha256 = sha256,
    }
end
