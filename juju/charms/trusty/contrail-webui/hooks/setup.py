import os
import shutil
import subprocess
from charmhelpers.core.services import (
    service_restart
)

def pre_install():
    """Do any setup required before the install hook."""
    install_charmhelpers()


def install_charmhelpers():
    """Install the charmhelpers library, if not present."""
    try:
        import charmhelpers  # noqa
    except ImportError:
        import subprocess
        subprocess.check_call(['apt-get', 'install', '-y', 'python-pip'])
        subprocess.check_call(['pip', 'install', 'charmhelpers'])


def fix_permissions():
    """Fix the config directory permisions."""
    os.chmod("/etc/contrail", 0o755)
    os.chown("/etc/contrail", 0, 0)

def fix_supervisor():
    subprocess.check_call(['useradd', '-r', 'contrail'])
    try:
        os.mkdir("/var/log/contrail")
    except:
        pass
    shutil.copy("files/supervisor-webui.conf", "/etc/init")
    os.chmod("/etc/init/supervisor-webui.conf", 0755)

    shutil.copy("files/supervisord_webui.conf", "/etc/contrail")
    try:
        os.mkdir("/etc/contrail/supervisord_webui_files")
    except:
        pass
    shutil.copy("files/supervisord_webui_files/contrail-webui.ini",
        "/etc/contrail/supervisord_webui_files")
    shutil.copy("files/supervisord_webui_files/contrail-webui-middleware.ini",
        "/etc/contrail/supervisord_webui_files")
    service_restart("supervisor-webui")

