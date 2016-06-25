# -*- coding: utf-8 -*-
'''
:maintainer: Sylvain Viart (sylvain303@github)
:maturity: 20160522
:requires: none
:platform: all
'''

from __future__ import absolute_import
import logging
import re

LOG = logging.getLogger(__name__)

__virtualname__ = 'mysql'


def __virtual__():
    '''
    Determine whether or not to load this module
    '''
    return True

def remove_all_non_admin_user(**connection_args):
    '''
    "remove_all_non_admin_user" remove all non root users from the database.
    Only root and debian-sys-maint are preserved.

    CLI Example:

    .. code-block:: bash

        salt '*' mysql.remove_all_non_admin_user
    '''
    LOG.debug('Executing mysql.remove_all_non_admin_user')
    query="""
        DELETE FROM user WHERE user NOT IN('root', 'debian-sys-maint');
        DELETE FROM db;
        DELETE FROM columns_priv;
        FLUSH PRIVILEGES;
        """
    res = __salt__['mysql.query']('mysql', query, **connection_args)
    LOG.debug(res)

    res = __salt__['mysql.user_list']()
    LOG.debug(res)

    return res

def cleanup_users(drop_extra = [], keep_extra = [], **connection_args):
    '''
    "cleanup_users" remove all non managed users from the database.
    Managed users are calculated from the pillar.

    CLI Example:

    .. code-block:: bash

        salt '*' mysql.cleanup_users
    '''
    LOG.debug('Executing mysql.cleanup_users')
    drop_users = list_user_to_drop(drop_extra, keep_extra, **connection_args)
    query="""
        DELETE FROM user WHERE CONCAT(user, '@', host) IN(%(drop)s);
        DELETE FROM db WHERE CONCAT(user, '@', host) IN(%(drop)s);
        DELETE FROM columns_priv WHERE CONCAT(user, '@', host) IN(%(drop)s);
        FLUSH PRIVILEGES;
        """ % dict(drop="'" + "','".join(drop_users) + "'")
    res = __salt__['mysql.query']('mysql', query, **connection_args)
    LOG.debug(res)

    res = drop_users
    return res

debian_keep = ['root@%', 'debian-sys-maint@localhost']

def list_user_managed(keep_extra = [], drop_extra = []):
    '''
    "list_user_managed" list all managed users according to pillar data

    CLI Example:

    .. code-block:: bash

        salt '*' mysql.list_user_managed
        salt '*' mysql.list_user_managed keep_extra="['root@%', 'debian-sys-maint@localhost']"
    '''

    LOG.debug('Executing mysql.list_user_managed')
    managed = []
    regexp = re.compile(r'^(%s)$' % _get_user_regexp(drop_extra))
    LOG.debug(regexp)
    for user, info in __salt__['pillar.get']('mysql:user', {}).items():
        # single or many host
        hosts = info.get('hosts', [info.get('host')])
        for h in hosts:
            # if the user as no host entry (absent: True), ignore it.
            # will be deleted.
            if h:
                s = user + '@' + h
                if re.search(regexp, s):
                    continue
                managed.append(s)

    if len(keep_extra) > 0:
        managed += keep_extra

    LOG.debug(managed)
    return managed

def list_user_to_keep(keep_extra = [], drop_extra = []):
    '''
    "list_user_to_keep" list all users that will be kept by cleanup_users()

    CLI Example:

    .. code-block:: bash

        salt '*' mysql.list_user_to_keep
    '''
    LOG.debug('Executing mysql.list_user_tokeep')
    to_keep = list_user_managed(debian_keep + keep_extra, drop_extra)

    return to_keep

def _get_user_regexp(managed):
    # adapt managed user wildcards
    i = 0
    for u in managed:
        if '.' in u:
            managed[i] = u.replace('.', '\.')
        if '%' in u:
            managed[i] = u.replace('%', '.*')
        i += 1

    regexp = "|".join(managed)
    return regexp

def list_user_to_drop(drop_extra = [], keep_extra = [], **connection_args):
    '''
    "list_user_to_drop" list all users that will be droped by cleanup_users()

    CLI Example:

    .. code-block:: bash

        salt '*' mysql.list_user_to_drop
    '''
    LOG.debug('Executing mysql.list_user_to_drop')
    managed = list_user_to_keep(keep_extra, drop_extra)
    regexp = _get_user_regexp(managed)
    clause = "CONCAT(user, '@', host) NOT regexp '^(%s)$'" % regexp
    query= "SELECT CONCAT(user, '@', host) as user FROM user WHERE %s;" % clause
    LOG.debug(query)
    res = __salt__['mysql.query']('mysql', query, **connection_args)
    LOG.debug(res)

    # format as a list, as they are tuple
    return [ u[0] for u in res['results'] ]
