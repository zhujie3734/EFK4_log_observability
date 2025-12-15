function parse_pa_log(tag, timestamp, record)
    local msg = record["message"]
    if not msg then
        return -1, timestamp, record
    end

    local traffic_pattern =
        "(%d+/%d+/%d+ %d+:%d+:%d+)%s+" ..
        "(%d+%.%d+%.%d+%.%d+)%s+" ..
        "(%S+)%s+" ..
        "(%d+%.%d+%.%d+%.%d+)%s+" ..
        "(%d+)%s+" ..
        "(%S+)%s+" ..
        "(%S+)%s+" ..
        "(%S+)"

    local datetime, src_ip, user, dst_ip, port, app, category, catype =
        string.match(msg, traffic_pattern)

    if datetime then
        local new_record = {
            log_type     = "pa_traffic_log",
            datetime = datetime,
            src_ip   = src_ip,
            user     = user,
            dst_ip   = dst_ip,
            port     = tonumber(port),
            app      = app,
            category = category,
            catype   = catype
        }
        return 1, timestamp, new_record
    end


    local alert_pattern =
       "(%S+)%s+" ..
       "(%S+)%s+" ..
       "\"([^\"]+)\"%s+" ..
       "\"([^\"]+)\""       

    local action, user2, classification, url =
        string.match(msg, alert_pattern)

    if user2 then
        local new_record = {
            log_type       = "pa_url_log",
            action         = action,
            user           = user2,
            classification = classification,
            url            = url
        }
        return 1, timestamp, new_record
    end

    return -1, timestamp, record
end
