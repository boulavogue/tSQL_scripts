/***
Lists all queries executed by a user (returns what is in the cache). 
When the server is rebooted (probably nightly), the cache is cleared.
***/

USE master
go
SELECT sdest.DatabaseName 
    ,sdes.session_id
    ,sdes.[host_name]
    ,sdes.[program_name]
    ,sdes.client_interface_name
    ,sdes.login_name
    ,sdes.login_time
    ,sdes.nt_domain
    ,sdes.nt_user_name
    ,sdec.client_net_address
    ,sdec.local_net_address
    ,sdest.ObjName
    ,sdest.Query
FROM sys.dm_exec_sessions AS sdes
INNER JOIN sys.dm_exec_connections AS sdec ON sdec.session_id = sdes.session_id
CROSS APPLY (
    SELECT db_name(dbid) AS DatabaseName
        ,object_id(objectid) AS ObjName
        ,ISNULL((
                SELECT TEXT AS [processing-instruction(definition)]
                FROM sys.dm_exec_sql_text(sdec.most_recent_sql_handle)
                FOR XML PATH('')
                    ,TYPE
                ), '') AS Query

    FROM sys.dm_exec_sql_text(sdec.most_recent_sql_handle)
    ) sdest
where sdes.session_id <> @@SPID 
and sdes.nt_user_name = 'boulavogue' -- Put the username here !
ORDER BY sdec.session_id
