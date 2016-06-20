{#-
# vim: set ft=jinja:
This state handle creation and deletion of mysql's user.
-#}
{#-
===== FETCH DATA =====
-#}
{% from "mysql/defaults.yaml" import rawmap with context %}
{%- set mysql = salt['grains.filter_by'](rawmap, grain='os', merge=salt['pillar.get']('mysql:server:lookup')) %}
{%- set mysql_root_user = salt['pillar.get']('mysql:server:root_user', 'root') %}
{%- set mysql_root_pass = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{%- set mysql_host = salt['pillar.get']('mysql:server:host', 'localhost') %}
{% set mysql_salt_user = salt['pillar.get']('mysql:salt_user:salt_user_name', mysql_root_user) %}
{% set mysql_salt_pass = salt['pillar.get']('mysql:salt_user:salt_user_password', mysql_root_pass) %}

{% set user_states = [] %}
{% set user_hosts = [] %}
{#-
===== MACRO DEFINITION =====
-#}
{# this macro is for DRY connection to the database #}
{%- macro mysql_root_connection() %}
    - connection_host: '{{ mysql_host }}'
    - connection_user: '{{ mysql_salt_user }}'
      {%- if mysql_salt_pass %}
    - connection_pass: '{{ mysql_salt_pass }}'
      {%- endif %}
    - connection_charset: utf8
{% endmacro -%}

{# this macro is the salt statement to remove a user #}
{%- macro mysql_user_remove(name, host, where) %}
{%- set state_id = 'mysql_user_remove_' ~ name ~ '_' ~ host %}
{{ state_id }}:
  # {{ where }}
  mysql_user.absent:
    - name: {{ name }}
    - host: '{{ host }}'
    {{ mysql_root_connection() }}
{% endmacro -%}

{#- this macro is a salt state fully destroy a user from mysql tables
it is an experimental macro… use with caution!
-#}
{% macro mysql_user_destroy(name) %}
{%- set state_id = 'mysql_user_destroy_' ~ name %}
{%- set queries = "
DELETE FROM columns_priv WHERE user = '" ~ name ~ "';
DELETE FROM db    WHERE user = '" ~  name ~ "';
DELETE FROM user  WHERE user = '" ~ name ~"';
FLUSH PRIVILEGES;
" %}
{{ state_id }}:
  module.run:
    - name: mysql.query
    - database: mysql
    - query: "{{ queries }}"
    {{ mysql_root_connection() }}
{% endmacro -%}
{#-
===== MAIN OUTPUT=====
-#}
include:
  - mysql.python
{#-
===== LOOP OVER DATA : users =====
-#}
{% for name, user in salt['pillar.get']('mysql:user', {}).items() %}
{#-
   >> select multiples host for the same user host: or hosts: in pillar =====
-#}
{% set user_host = salt['pillar.get']('mysql:user:%s:host'|format(name)) %}
{% if user_host != '' %}
  {% set user_hosts = [user_host] %}
{% else %}
  {% set user_hosts = salt['pillar.get']('mysql:user:%s:hosts'|format(name)) %}
{% endif %}
{#-
   >> fetch something about mine, used to overwrite user_hosts at the end
-#}
{% if not user_hosts %}
  {% set mine_target = salt['pillar.get']('mysql:user:%s:mine_hosts:target'|format(name)) %}
  {% set mine_function = salt['pillar.get']('mysql:user:%s:mine_hosts:function'|format(name)) %}
  {% set mine_expression_form = salt['pillar.get']('mysql:user:%s:mine_hosts:expr_form'|format(name)) %}

  {% if mine_target and mine_function and mine_expression_form %}
    {% set user_hosts = salt['mine.get'](mine_target, mine_function, mine_expression_form).values() %}
  {% endif %}
{% endif %}
{#-
  ===== INNER LOOP OVER DATA : host -> fecthed above single or multiple =====
-#}
{% for host in user_hosts %}
{% if user.absent is defined and user.absent %}
{{ mysql_user_remove(name, host, 'top') }}
{% else %}
{#-
  CREATE USER
-#}
{% set state_id = 'mysql_user_' ~ name ~ '_' ~ host %}
{{ state_id }}:
  mysql_user.present:
    - name: {{ name }}
    - host: '{{ host }}'
  {%- if user['password_hash'] is defined %}
    - password_hash: '{{ user['password_hash'] }}'
  {%- elif user['password'] is defined and user['password'] != None %}
    - password: '{{ user['password'] }}'
  {%- else %}
    - allow_passwordless: True
  {%- endif %}
    - connection_host: '{{ mysql_host }}'
    - connection_user: '{{ mysql_salt_user }}'
    {% if mysql_salt_pass %}
    - connection_pass: '{{ mysql_salt_pass }}'
    {% endif %}
    - connection_charset: utf8

{%- if 'grants' in user %}
{{ state_id ~ '_grants' }}:
  mysql_grants.present:
    - name: {{ name }}
    - grant: {{ user['grants']|join(",") }}
    - database: '*.*'
    - grant_option: {{ user['grant_option'] | default(False) }}
    - user: {{ name }}
    - host: '{{ host }}'
    - connection_host: localhost
    - connection_user: '{{ mysql_salt_user }}'
    {% if mysql_salt_pass -%}
    - connection_pass: '{{ mysql_salt_pass }}'
    {% endif %}
    - connection_charset: utf8
    - require:
      - mysql_user: {{ state_id }}
{% endif %}

{%- if 'databases' in user %}
{% for db in user['databases'] %}
{{ state_id ~ '_' ~ loop.index0 }}:
  mysql_grants.present:
    - name: {{ name ~ '_' ~ db['database']  ~ '_' ~ db['table'] | default('all') }}
    - grant: {{db['grants']|join(",")}}
    - database: '{{ db['database'] }}.{{ db['table'] | default('*') }}'
    - grant_option: {{ db['grant_option'] | default(False) }}
    - user: {{ name }}
    - host: '{{ host }}'
    - connection_host: '{{ mysql_host }}'
    - connection_user: '{{ mysql_salt_user }}'
    {% if mysql_salt_pass -%}
    - connection_pass: '{{ mysql_salt_pass }}'
    {% endif %}
    - connection_charset: utf8
    - require:
      - mysql_user: {{ state_id }}
{% endfor %}
{% endif %}

{# collect added user for mysql/init.sls for requisites #}
{% do user_states.append(state_id) %}

{# END user.absent #}
{% endif %}
{#-
  =============== END FOR host
-#}
{% endfor %}

{#-
extra remove user with multiples host see #119 for user.hosts_absent (list)
must be in user loop not in host loop.
-#}
{% set user_hosts_absent = salt['pillar.get']('mysql:user:%s:hosts_absent'|format(name)) %}
{% if user_hosts_absent != '' %}
  {% for h in user_hosts_absent %}
    {{ mysql_user_remove(name, h, 'end') }}
  {% endfor %}
{% endif %}
{#-
  =============== END FOR user
-#}
{% endfor %}
