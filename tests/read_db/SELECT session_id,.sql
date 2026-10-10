SELECT session_id,
       datetime(CAST(substr(session_id, 1, 13) AS INTEGER) / 1000,
                'unixepoch', 'localtime') AS id_time,
       started_at
FROM sessions;

