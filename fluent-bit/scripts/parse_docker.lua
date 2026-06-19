local container_map = dofile("/etc/fluent-bit/scripts/container_map.lua")

local function extract_container_id(path)
    if path == nil then
        return nil
    end

    return string.match(path, "/containers/([a-f0-9]+)/")
end

local function normalize_name(value)
    if value == nil or value == "" then
        return "unknown"
    end

    value = string.lower(value)
    value = string.gsub(value, "[^%w%-_%.]", "_")
    return value
end

local function parse_dotnet_console_log(message)
    local parsed = {}

    local log_time, level, logger, event_id, detail =
        string.match(
            message,
            "^%[(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%.%d%d%d)%]%s+(%w+):%s+([^%[]+)%[(%d+)%]%s*\n?%s*(.*)"
        )

    parsed["app_log_time"] = log_time
    parsed["log_level"] = level
    parsed["logger"] = logger
    parsed["event_id"] = event_id
    parsed["log_message"] = detail

    return parsed
end

local function detect_event_status(message, level)
    local lower_message = string.lower(message or "")
    local lower_level = string.lower(level or "")

    if lower_level == "error" then
        return "failed"
    end

    if string.find(lower_message, "failed")
        or string.find(lower_message, "fail")
        or string.find(lower_message, "exception")
        or string.find(lower_message, "error") then
        return "failed"
    end

    return "normal"
end

function parse_docker_log(tag, timestamp, record)
    local path = record["docker_log_path"]
    local container_id = extract_container_id(path)

    record["source_type"] = "docker"
    record["container_id"] = container_id or "unknown"

    local meta = nil
    if container_id ~= nil then
        meta = container_map[container_id]
    end

    if meta == nil then
        record["container_name"] = "unknown"
        record["service_name"] = "unknown"
        record["service_type"] = "unknown"
        record["env"] = "unknown"
    else
        record["container_name"] = meta["container_name"] or "unknown"
        record["service_name"] = meta["service_name"] or record["container_name"]
        record["service_type"] = meta["service_type"] or "unknown"
        record["env"] = meta["env"] or "prod"
    end

    local message = record["log"] or record["message"] or ""
    local parsed = parse_dotnet_console_log(message)

    record["message"] = message
    record["app_log_time"] = parsed["app_log_time"]
    record["log_level"] = normalize_name(parsed["log_level"] or "unknown")
    record["logger"] = parsed["logger"] or "unknown"
    record["event_id"] = parsed["event_id"] or "unknown"
    record["log_message"] = parsed["log_message"] or message

    record["event_status"] = detect_event_status(record["log_message"], record["log_level"])

    local route_container = normalize_name(record["container_name"])
    local route_level = normalize_name(record["log_level"])
    local route_status = normalize_name(record["event_status"])

    record["route_key"] = route_container .. "." .. route_level .. "." .. route_status

    return 1, timestamp, record
end