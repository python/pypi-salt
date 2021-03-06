
include:
  - tls

/etc/pki/rpm-gpg/RPM-GPG-KEY-NGINX:
  file.managed:
    - source: salt://nginx/config/RPM-GPG-KEY-NGINX
    - user: root
    - group: root
    - mode: 444

nginx-release:
  pkgrepo.managed:
    - humanname: nginx CentOS YUM repository
    - baseurl: http://nginx.org/packages/centos/$releasever/$basearch/
    - gpgcheck: 1
    - gpgkey: file:///etc/pki/rpm-gpg/RPM-GPG-KEY-NGINX
    - require:
      - file: /etc/pki/rpm-gpg/RPM-GPG-KEY-NGINX

nginx:
  user.present:
    - system: True
    - shell: /sbin/nologin
    - groups:
      - nginx
    - require:
      - group: nginx
  group.present:
    - system: True
  pkg:
    - installed
    - require:
      - pkgrepo: nginx-release
  service:
    - running
    - enable: True
    - reload: True
    - watch:
      - file: /etc/nginx/nginx.conf
      - file: /etc/nginx/nginx.ssl.conf
      - file: /etc/nginx/conf.d/*
    - require:
      - file: /etc/nginx/nginx.conf
      - pkg: nginx
      - user: nginx

/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://nginx/config/nginx.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: /var/log/nginx

/etc/nginx/nginx.ssl.conf:
  file.managed:
    - source: salt://nginx/config/nginx.ssl.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - sls: tls

/etc/logrotate.d/nginx:
  file.managed:
    - source: salt://nginx/config/nginx.logrotate
    - user: root
    - group: root
    - mode: 644

/var/log/nginx:
  file.directory:
    - user: nginx
    - group: root
    - mode: 0755

/etc/nginx/conf.d/default.conf:
  file.absent

/etc/nginx/conf.d/virtual.conf:
  file.absent

/etc/nginx/conf.d/ssl.conf:
  file.absent

{% if 'datadog_api_key' in pillar %}
/etc/dd-agent/conf.d/nginx.yaml:
  file.managed:
    - user: root
    - group: root
    - mode: '0644'
    - contents: |
        init_config:
        instances:
            -   nginx_status_url: http://127.0.0.1/nginx_status/
{% endif %}
