local http = require("http")
local json = require("json")
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

    local filename = "iyi-" .. version .. "-" .. target .. "." .. ext
    local dir = iyi.downloads .. "/v" .. version

    -- Look the release up first, so a missing platform archive says so
    -- instead of failing later with an opaque HTTP 404.
    local resp, err = http.get({ url = iyi.api .. "/releases/tags/v" .. version })
    if err ~= nil then
        error("failed to fetch iyi " .. version .. ": " .. err)
    end
    if resp.status_code == 404 then
        error("iyi " .. version .. " is not a published release")
    elseif resp.status_code ~= 200 then
        error("GitHub API returned " .. resp.status_code .. ": " .. resp.body)
    end

    local release = json.decode(resp.body)
    local asset = iyi.find_asset(release, filename)
    if asset == nil then
        error("iyi " .. version .. " has no " .. filename .. " for this platform")
    end

    -- The GitHub API exposes the asset digest; fall back to the release's
    -- SHA256SUMS for releases that predate it. Releases before 0.12.0
    -- published neither, and are installed unverified with a warning.
    local sha256 = nil
    if asset.digest ~= nil then
        sha256 = asset.digest:match("^sha256:(%x+)$")
    end

    if sha256 == nil then
        local sums, sums_err = http.get({ url = dir .. "/SHA256SUMS" })
        if sums_err ~= nil then
            error("failed to fetch SHA256SUMS for iyi " .. version .. ": " .. sums_err)
        end
        if sums.status_code == 200 then
            sha256 = iyi.find_checksum(sums.body, filename)
            if sha256 == nil then
                error("SHA256SUMS for iyi " .. version .. " has no entry for " .. filename)
            end
        elseif sums.status_code == 404 and iyi.version_lt(version, "0.12.0") then
            log.warn("iyi " .. version .. " publishes no SHA256SUMS; the download is not verified")
        else
            error("could not fetch " .. dir .. "/SHA256SUMS (HTTP " .. sums.status_code .. ")")
        end
    end

    return {
        version = version,
        url = dir .. "/" .. filename,
        sha256 = sha256,
    }
end
