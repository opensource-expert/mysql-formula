# vim: set ft=yaml:
{% load_pillar mysql  %}
{% load_logic for mysql  %}

{# this macro is the salt statement to remove a user #}
{% macro mysql_user_remove(name, host) %}
{% set state_id = 'mysql_user_remove_' ~ name ~ '_' ~ host %}
{{ state_id }}:
  mysql_user.absent:
    - name: {{ name }}
    - host: '{{ host }}'
    {{ mysql_server_connection(mysql.mysql_host, mysql.mysql_salt_user, mysql.mysql_salt_pass) }}
{% endmacro %}


{% macro mysql_user_create(name, host) %}
{% set state_id = 'mysql_user_create_' ~ name ~ '_' ~ host%}
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
    {{ mysql_server_connection(mysql.mysql_host, mysql.mysql_salt_user, mysql.mysql_salt_pass) }}
{% endmacro %}

{% macro mysql_grant_all_user(name, user) %}
{{ state_id ~ '_grants' }}:
  mysql_grants.present:
    - name: {{ name }}
    - grant: {{ user['grants']|join(",") }}
    - database: '*.*'
    - grant_option: {{ user['grant_option'] | default(False) }}
    - user: {{ name }}
    - host: '{{ host }}'
    {{ mysql_server_connection(mysql.mysql_host, mysql.mysql_salt_user, mysql.mysql_salt_pass) }}
    - require:
      - mysql_user: {{ state_id }}
{% endmacro %}

{% macro mysql_grant_user(name, user, db) %}
{{ state_id ~ '_grants_' ~ loop.index0 }}:
  mysql_grants.present:
    - name: {{ name ~ '_' ~ db['database']  ~ '_' ~ db['table'] | default('all') }}
    - grant: {{db['grants']|join(",")}}
    - database: '{{ db['database'] }}.{{ db['table'] | default('*') }}'
    - grant_option: {{ db['grant_option'] | default(False) }}
    - user: {{ name }}
    - host: '{{ host }}'
    {{ mysql_server_connection(mysql.mysql_host, mysql.mysql_salt_user, mysql.mysql_salt_pass) }}
    - require:
      - mysql_user: {{ state_id }}
{% endmacro %}

### ----------------------------- Main loop

{% for name, user in mysql.users %}
  {% for host in user_hosts(user) %}
    {% if user_is_absent(user) %}
      {{- mysql_user_remove(name, host) }}
    {% elif user_is_removed_from_host(user, host) %}
      {{- mysql_user_remove(name, host) }}
    {% else %}
      {{- mysql_user_create(name, host) }}
    {% endif %}

    {%- if 'grants' in user %}
      {{- mysql_grant_all_user(name, host) }}
    {% endif %}

    {%- if 'databases' in user %}
      {% for db in user['databases'] %}
        {{- mysql_grant_user(name, user, db) }}
      {% endfor %}
    {% endif %}

{% endfor %}
