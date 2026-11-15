-- Shared helpers for the mise tool plugin (Lua 5.1, as embedded by mise).

local M = {}

-- Git's smart-HTTP ref advertisement. Unlike the GitHub API this needs no
-- token and is not subject to the unauthenticated request limit.
M.refs = "https://github.com/iyilang/iyi.git/info/refs?service=git-upload-pack"
M.downloads = "https://github.com/iyilang/iyi/releases/download"

-- iyi publishes a compiler for these targets only.
local OS_NAMES = { linux = "linux", darwin = "darwin", windows = "windows" }
local ARCH_NAMES = { amd64 = "x86_64", arm64 = "arm64" }

-- The first release that carries an archive for each target. Linux has had
-- an x86_64 archive since 0.1.0.
local FIRST_RELEASE = {
    ["darwin-arm64"] = "0.5.1",
    ["windows-x86_64"] = "0.14.0",
}

-- Returns the release target ("linux-x86_64", ...) and archive extension,
-- or nil when iyi does not publish a compiler for this platform. RUNTIME
-- describes the target platform, including during `mise lock`.
function M.target()
    local os = OS_NAMES[(RUNTIME.osType or ""):lower()]
    if os == nil then
        return nil, nil
    end

    local arch = ARCH_NAMES[RUNTIME.archType]
    if arch == nil then
        return nil, nil
    end

    -- Linux releases are glibc builds; a musl system cannot run them.
    if os == "linux" and RUNTIME.envType == "musl" then
        return nil, nil
    end

    if os == "linux" and arch ~= "x86_64" then
        return nil, nil
    elseif os == "darwin" and arch ~= "arm64" then
        return nil, nil
    elseif os == "windows" and arch ~= "x86_64" then
        return nil, nil
    end

    local ext = os == "windows" and "zip" or "tar.gz"
    return os .. "-" .. arch, ext
end

-- Target for the machine running this hook, with a clear error when iyi has
-- no release for it. Version listing must fail rather than return nothing.
function M.host_target()
    local os = tostring(RUNTIME.osType) .. "-" .. tostring(RUNTIME.archType)
    local target, ext = M.target()
    if target == nil then
        error("iyi has no release for " .. os .. ": releases ship Linux x86_64 (glibc), macOS arm64 and Windows x86_64")
    end
    return target, ext
end

-- Tag "v0.21.0" -> "0.21.0"; anything that is not a release version -> nil.
function M.normalize(tag)
    local version = (tag or ""):gsub("^v", "")
    if version:match("^%d+%.%d+%.%d+$") then
        return version
    end
    return nil
end

-- Find one file's SHA-256 in a SHA256SUMS body. Compare names exactly:
-- "." and "-" are pattern characters, so line:match(filename) is not exact.
function M.find_checksum(body, filename)
    for line in body:gmatch("[^\r\n]+") do
        local digest, name = line:match("^(%x+)%s+%*?(.+)$")
        if name == filename and #digest == 64 then
            return digest
        end
    end
    return nil
end

-- True when dotted version $1 sorts before $2.
function M.version_lt(a, b)
    local function parts(version)
        local out = {}
        for number in version:gmatch("%d+") do
            table.insert(out, tonumber(number))
        end
        return out
    end

    local left, right = parts(a), parts(b)
    for i = 1, math.max(#left, #right) do
        local x, y = left[i] or 0, right[i] or 0
        if x < y then
            return true
        elseif x > y then
            return false
        end
    end
    return false
end

-- True when this release has an archive for this target.
function M.supports(version, target)
    local first = FIRST_RELEASE[target]
    if first == nil then
        return true
    end
    return not M.version_lt(version, first)
end

return M
