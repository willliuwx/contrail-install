import os
import urllib

import actions
from charmhelpers.core import hookenv
from charmhelpers.core import services
from charmhelpers.core import templating

CONFIG_FILE = os.path.join(os.sep, 'etc', 'contrail', 'config.global.js')


class CassandraRelation(services.RelationContext):
    name = 'cassandra'
    interface = 'cassandra'
    required_keys = ['private-address']


class ContrailAPIRelation(services.RelationContext):
    name = 'contrail_api'
    interface = 'contrail-api'
    required_keys = ['private-address', 'port']


class ContrailDiscoveryRelation(services.RelationContext):
    name = 'contrail_discovery'
    interface = 'contrail-discovery'
    required_keys = ['private-address', 'port']


class KeystoneRelation(services.RelationContext):
    name = 'identity_admin'
    interface = 'keystone-admin'
    required_keys = ['service_hostname', 'service_port', 'service_username',
            'service_tenant_name', 'service_password']


class RedisRelation(services.RelationContext):
    name = 'redis'
    interface = 'redis-master'
    required_keys = ['hostname', 'port']


class ContrailWebUIConfig(services.ManagerCallback):
    def __call__(self, manager, service_name, event_name):
        context = {
            'config': hookenv.config()
        }
        context.update(ContrailAPIRelation())
        context.update(ContrailDiscoveryRelation())
        context.update(CassandraRelation())
        context.update(KeystoneRelation())

        # Redis relation is optional
        redis = RedisRelation()
        if redis.is_ready():
            context.update(redis)
        else:
            context.update({
                'redis': [{
                    'hostname': '127.0.0.1',
                    'port': '6379'
                }]
            })

        # Download logo and favicon or use the cached one
        # if failed, falling back to the defaults
        for target in ('logo', 'favicon'):
            url = context['config']['{0}-url'.format(target)]
            filename = os.path.join(os.sep, 'etc', 'contrail',
                                    os.path.basename(url))
            context['config']['{0}-filename'.format(target)] = ''
            if url:
                try:
                    urllib.urlretrieve(url, filename)
                except IOError:
                    pass

                try:
                    if os.stat(filename).st_size > 0:
                        context['config']['{0}-filename'.format(target)] = (
                            filename
                        )
                except OSError:
                    pass

        templating.render(
            context=context,
            source='config.global.js.j2',
            target=CONFIG_FILE,
            perms=0o644
        )

        templating.render(
            context=context,
            source='contrail-webui-userauth.js',
            target='/etc/contrail/contrail-webui-userauth.js',
            perms=0o640,
            owner='root',
            group='contrail'
        )


class ContrailWebRelation(services.ManagerCallback):
    def __call__(self, manager, service_name, event_name):
        data = {
            'host': None,
            'port': None,
        }

        config = hookenv.config()
        if event_name == 'data_ready':
            data['host'] = hookenv.unit_private_ip(),
            data['port'] = config['port']

        for relation in hookenv.relation_ids('website'):
            hookenv.relation_set(relation, **data)


def manage():
    config = hookenv.config()
    cassandra = CassandraRelation()
    contrail_api = ContrailAPIRelation()
    contrail_discovery = ContrailDiscoveryRelation()
    keystone = KeystoneRelation()

    config_callback = ContrailWebUIConfig()
    website_callback = ContrailWebRelation()

    manager = services.ServiceManager([
        {
            'service': 'contrail-webui-webserver',
            'ports': (config['port'],),
            'required_data': [
                config,
                cassandra,
                contrail_api,
                contrail_discovery,
                keystone,
            ],
            'data_ready': [
                actions.log_start,
                config_callback,
                website_callback,
            ],
            'data_lost': [
                website_callback,
            ]
        },
        {
            'service': 'contrail-webui-jobserver',
            'required_data': [
                config,
                cassandra,
                contrail_api,
                contrail_discovery,
                keystone,
            ],
            'data_ready': [
                actions.log_start,
                config_callback,
            ],
        },
    ])
    manager.manage()
