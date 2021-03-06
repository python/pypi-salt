
include:
  - python.27.virtualenv
  - pkg.git

pypi-system-deps:
  pkg.installed:
    - pkgs:
      - python27-devel
      - postgresql-devel
      - gcc
      - openssl-devel
      - libffi-devel
    - require:
      - pkgrepo: ewdurbin-pythons-el6


# Fix an error with Elastcisearch's IPv6 going sideways
net.ipv6.conf.all.disable_ipv6:
  sysctl.present:
    - value: 1

{% set deploys = {} %}
{% for k,v in pillar.items() %}
  {% if k.startswith('pypi-deploy-') %}
    {% do deploys.update({k: v}) %}
  {% endif %}
{% endfor %}

{% for key, config in deploys.items() %}

{{ config['name'] }}-user:
  group.present:
    - name: {{ config['group'] }}
    - gid: {{ config['group_gid'] }}
  user.present:
    - name: {{ config['user'] }}
    - uid: {{ config['user_uid'] }}
    - gid: {{ config['group_gid'] }}
    - home: {{ config['path'] }}
    - createhome: True
    - require:
      - group: {{ config['group'] }}

{{ config['path'] }}:
  file.directory:
    - user: {{ config['user'] }}
    - group: {{ config['group'] }}
    - mode: 755

/var/log/{{ config['name'] }}:
  file.directory:
    - user: {{ config['user'] }}
    - group: {{ config['group'] }}
    - mode: 750

/var/run/{{ config['name'] }}:
  file.directory:
    - user: {{ config['user'] }}
    - group: {{ config['group'] }}
    - mode: 755

{{ config['name'] }}-source:
  git.latest:
    - name: {{ config.get('source_uri', "https://github.com/pypa/pypi-legacy.git") }}
    - rev: {{ config.get('source_rev', "master") }}
    - target: {{ config['path'] }}/src
    - user: {{ config['name'] }}
    - require:
      - user: {{ config['name'] }}
      - file: {{ config['path'] }}

/opt/{{ config['name'] }}/env:
  virtualenv.managed:
    - venv_bin: /usr/bin/virtualenv
    - python: /usr/bin/python2.7
    - system_site_packages: {{ config.get('site_packages', True) }}
    - user: {{ config['name'] }}
    - cwd: {{ config['path'] }}/src
    - requirements: {{ config['path'] }}/src/requirements.txt
    - require:
      - file: {{ config['path'] }}
      - git: {{ config['name'] }}-source
      - user: {{ config['user'] }}
      - pip: virtualenv-2.7
      - pkg: pypi-system-deps

/opt/{{ config['name'] }}/uwsgi/plugins:
  file.directory:
    - user: {{ config['user'] }}
    - group: {{ config['group'] }}
    - mode: 755
    - makedirs: True

{{ config['name'] }}_initial_build_dogstatsd_uwsgi:
  cmd.run:
    - creates: /opt/{{ config['name'] }}/uwsgi/plugins/dogstatsd_plugin.so
    - name: "/opt/{{ config['name'] }}/env/bin/uwsgi --build-plugin https://github.com/Datadog/uwsgi-dogstatsd"
    - user: {{ config['user'] }}
    - cwd: /opt/{{ config['name'] }}/uwsgi/plugins

{{ config['name'] }}_build_dogstatsd_uwsgi:
  cmd.run:
    - onchanges:
      - virtualenv: /opt/{{ config['name'] }}/env
    - name: "/opt/{{ config['name'] }}/env/bin/uwsgi --build-plugin https://github.com/Datadog/uwsgi-dogstatsd"
    - user: {{ config['user'] }}
    - cwd: /opt/{{ config['name'] }}/uwsgi/plugins

{{ config['path'] }}/src/config.ini:
  file.managed:
    - source: salt://pypi/config/pypi.ini.jinja
    - user: {{ config['name'] }}
    - group: {{ config['name'] }}
    - mode: 640
    - template: jinja
    - context:
      app_key: {{ key }}
    - require:
      - file: /var/log/{{ config['name'] }}
      - file: /var/run/{{ config['name'] }}
      - virtualenv: {{ config['path'] }}/env

{% endfor %}
