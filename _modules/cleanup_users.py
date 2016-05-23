# -*- coding: utf-8 -*-
'''
:maintainer: Sylvain Viart (sylvain303@github)
:maturity: 20160522
:requires: none
:platform: all
'''

from __future__ import absolute_import
import logging

LOG = logging.getLogger(__name__)

__virtualname__ = 'mysql'


def __virtual__():
    '''
    Determine whether or not to load this module
    '''
    return True

def mysql_cleanup_users(extra_keep=None, **connection_args):
    '''
    "mysql_cleanup_users" remove all non root users from the database;
    only root and debian-sys-maint are preserved

    CLI Example:

    .. code-block:: bash

        salt '*' mysql.cleanup_users
    '''
    LOG.debug('Executing mysql_cleanup_users')
    query="""
        DELETE FROM user         WHERE user NOT IN('root', 'debian-sys-maint');
        DELETE FROM db;
        DELETE FROM columns_priv;
        FLUSH PRIVILEGES;
        """
    res = __salt__['mysql.query']('mysql', query)
    LOG.debug(res)

    query="SELECT user, host FROM user"
    res = __salt__['mysql.user_list']()
    LOG.debug(res)

    return res
