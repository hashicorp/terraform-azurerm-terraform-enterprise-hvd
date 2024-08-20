[OUTPUT]
    name         azure
    match        *
    Customer_ID  ${log_analytics_workspace_id}
    Shared_Key   ${log_analytics_access_key}
    Log_Type     tfe_fluent_bit