# coding=utf-8
import sys
import os

from setuptools import find_packages
from setuptools import setup

assert sys.version_info[0] == 3 and sys.version_info[1] >= 6, "hive requires Python 3.6 or newer"

VERSION = '0.0.1'

class GitRevisionProvider(object):
    """ Static class to provide version and git revision information"""

    @staticmethod
    def provide_git_revision():
        """ Evaluate version and git revision and save it to a version file
            Evaluation is based on VERSION variable and git describe if
            .git directory is present in tree.
            In case when .git is not available version and git_revision is taken
            from get_distribution call
        """
        if os.path.exists("./../../.git"):
            from subprocess import check_output
            command = 'git -C ./../../../ describe --tags --long --dirty'
            version = check_output(command.split()).decode('utf-8').strip()
            parts = version.split('-')
            if parts[-1] == 'dirty':
                sha = parts[-2]
            else:
                sha = parts[-1]
            git_revision = sha.lstrip('g')
            GitRevisionProvider._save_version_file(VERSION, git_revision)
            return git_revision
        else:
            from pkg_resources import get_distribution
            try:
                version, git_revision = get_distribution("hive").version.split("+")
                GitRevisionProvider._save_version_file(version, git_revision)
                return git_revision
            except:
                GitRevisionProvider._save_version_file(VERSION, "")
        return ""

    @staticmethod
    def _save_version_file(hive_version, git_revision):
        """ Helper method to save version.py with current version and git_revision """
        with open("version.py", 'w') as version_file:
            version_file.write("# generated by setup.py\n")
            version_file.write("# contents will be overwritten\n")
            version_file.write("VERSION = '{}'\n".format(hive_version))
            version_file.write("GIT_REVISION = '{}'".format(git_revision))

GIT_REVISION = GitRevisionProvider.provide_git_revision()

if __name__ == "__main__":
    setup(
        name='hive',
        version=VERSION + "+" + GIT_REVISION,
        description='Hive - Decentralizing the exchange of ideas and information',
        long_description= 'Hive is a Graphene based, social blockchain that was created as a fork of Steem and born on the core idea of decentralization.',
        packages=find_packages(exclude=['scripts']),
        setup_requires=[
            'pytest-runner',
        ],
        dependency_links=[
            'https://github.com/bcb/jsonrpcserver/tarball/8f3437a19b6d1a8f600ee2c9b112116c85f17827#egg=jsonrpcserver-4.1.3+8f3437a'
        ],
        install_requires=[
            'aiopg @ https://github.com/aio-libs/aiopg/tarball/862fff97e4ae465333451a4af2a838bfaa3dd0bc',
            'jsonrpcserver @ https://github.com/bcb/jsonrpcserver/tarball/8f3437a19b6d1a8f600ee2c9b112116c85f17827#egg=jsonrpcserver',
            'simplejson',
            'aiohttp',
            'certifi',
            'sqlalchemy',
            'funcy',
            'toolz',
            'maya',
            'ujson',
            'urllib3',
            'psycopg2-binary',
            'aiocache',
            'configargparse',
            'pdoc',
            'diff-match-patch',
            'prometheus-client',
            'psutil'
        ],

        entry_points={
            'console_scripts': [
                'hive=hive.cli:run',
            ]
        }
    )
