# vim: set ft=yaml:
# This file is a jinja script for auto configuration file for .sls files
#
# use it that way: {# {% import 'mysql/include-config.sls' as mysql %} #}
#
# it will provide some variables:
# - mysql.mysql = all config from defaults.yaml (mysql config)
# - mysql.users = pillar config
# you need to prefix variables with mysql. (import as …)
{% from "mysql/defaults.yaml" import rawmap with context %}

{%- set mysql = salt['grains.filter_by'](rawmap, grain='os', merge=salt['pillar.get']('mysql:server:lookup')) %}
{%- set mysql_root_user = salt['pillar.get']('mysql:server:root_user', 'root') %}
{%- set mysql_root_pass = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{%- set mysql_host = salt['pillar.get']('mysql:server:host', 'localhost') %}
{% set mysql_salt_user = salt['pillar.get']('mysql:salt_user:salt_user_name', mysql_root_user) %}
{% set mysql_salt_pass = salt['pillar.get']('mysql:salt_user:salt_user_password', mysql_root_pass) %}
{% set users = salt['pillar.get']('mysql:user', {}).items() %}

{% set user_states = [] %}
{% set user_hosts = [] %}
