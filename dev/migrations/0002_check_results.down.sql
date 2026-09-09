-- Drop child tables before the hypertable
DROP TABLE IF EXISTS check_results_plugin;
DROP TABLE IF EXISTS check_results_traceroute_hops;
DROP TABLE IF EXISTS check_results_traceroute;
DROP TABLE IF EXISTS check_results_udp_connect;
DROP TABLE IF EXISTS check_results_tcp_connect;
DROP TABLE IF EXISTS check_results_http_get;
DROP TABLE IF EXISTS check_results_ping;

-- Drop hypertable (TimescaleDB drops chunks automatically)
DROP TABLE IF EXISTS check_results;
