# vim: set ft=yaml:
{% from "mysql/defaults.yaml" import rawmap with context %}
{%- set mysql = salt['grains.filter_by'](rawmap, grain='os', merge=salt['pillar.get']('mysql:server:lookup')) %}
{%- set mysql_root_user = salt['pillar.get']('mysql:server:root_user', 'root') %}
{%- set mysql_root_pass = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{%- set mysql_host = salt['pillar.get']('mysql:server:host', 'localhost') %}
{% set mysql_salt_user = salt['pillar.get']('mysql:salt_user:salt_user_name', mysql_root_user) %}
{% set mysql_salt_pass = salt['pillar.get']('mysql:salt_user:salt_user_password', mysql_root_pass) %}

{% set user_states = [] %}
{% set user_hosts = [] %}

include:
  - mysql.python

{% for name, user in salt['pillar.get']('mysql:user', {}).items() %}

{% set user_host = salt['pillar.get']('mysql:user:%s:host'|format(name)) %}
{% if user_host != '' %}
  {% set user_hosts = [user_host] %}
{% else %}
  {% set user_hosts = salt['pillar.get']('mysql:user:%s:hosts'|format(name)) %}
{% endif %}

{% if not user_hosts %}
  {% set mine_target = salt['pillar.get']('mysql:user:%s:mine_hosts:target'|format(name)) %}
  {% set mine_function = salt['pillar.get']('mysql:user:%s:mine_hosts:function'|format(name)) %}
  {% set mine_expression_form = salt['pillar.get']('mysql:user:%s:mine_hosts:expr_form'|format(name)) %}

  {% if mine_target and mine_function and mine_expression_form %}
    {% set user_hosts = salt['mine.get'](mine_target, mine_function, mine_expression_form).values() %}
  {% endif %}
{% endif %}

{% for host in user_hosts %}

{% if user.absent is defined and user.absent %}
{% set state_id = 'mysql_user_remove_' ~ name ~ '_' ~ host%}
{{ state_id }}:
  mysql_user.absent:
    - name: {{ name }}
    - host: '{{ host }}'
    - connection_host: '{{ mysql_host }}'
    - connection_user: '{{ mysql_salt_user }}'
    {% if mysql_salt_pass %}
    - connection_pass: '{{ mysql_salt_pass }}'
    {% endif %}
    - connection_charset: utf8
{% endif %}

{% endfor %}
{% endfor %}
