
firewall:
  ports:
    - 5432

postgresql_cluster:
  primary_server: 172.16.57.5
  standby_servers:
    - 172.16.57.6
