# vim: set ft=yaml:
# See: https://github.com/saltstack-formulas/mysql-formula/issues/119
# Also read the instruction in include-config.sls
{% import 'mysql/include-config.sls' as mysql with context %}

{# this macro is the salt statement to remove a user #}
{% macro remove_user(name, host) %}
{% set state_id = 'mysql_user_remove_' ~ name ~ '_' ~ host %}
{{ state_id }}:
  mysql_user.absent:
    - name: {{ name }}
    - host: '{{ host }}'
    # remove user for all host
    - connection_host: '{{ mysql.mysql_host }}'
    - connection_user: '{{ mysql.mysql_salt_user }}'
      {% if mysql.mysql_salt_pass %}
    - connection_pass: '{{ mysql.mysql_salt_pass }}'
      {% endif %}
    - connection_charset: utf8
{% endmacro %}

include:
  - mysql.python

{# go through all user in the pillar, and look for absent ones #}
{% for name, user in mysql.users %}
  {# trick for multiple host with same username see github #55 #}
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

  {# normal remove user.absent = True #}
  {% for host in user_hosts %}
    {% if user.absent is defined and user.absent %}
      {{ remove_user(name, host) }}
    {% endif %}
  {% endfor %}

  {# extra remove see #119 for user.host_absent (list) #}
  {% set user_host_absent = salt['pillar.get']('mysql:user:%s:host_absent'|format(name)) %}
  {% if user_host_absent != '' %}
    {% for h in user_host_absent %}
      {{ remove_user(name, h) }}
    {% endfor %}
  {% endif %}
{% endfor %}
