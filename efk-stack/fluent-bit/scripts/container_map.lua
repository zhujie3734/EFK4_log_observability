return {
    ["replace-with-container-id"] = {
        container_name = "example.analytics.etl.worker",
        service_name = "example-worker",
        service_type = "etl",
        env = "uat"
    }
}
