# == Class: katello_devel
#
# Install and configure Katello for development
#
# === Parameters:
#
# $user::                     The Katello system user name
#
# $deployment_dir::           Location to deploy Katello to in development
#
# $oauth_key::                The oauth key for talking to the candlepin API
#
# $oauth_secret::             The oauth secret for talking to the candlepin API
#
# $post_sync_token::          The shared secret for pulp notifying katello about
#                             completed syncs
#
# $use_passenger::            Whether to use Passenger in development
#
# $db_type::                  The database type; 'postgres' or 'sqlite'
#
# $mongodb_path::             Path where mongodb should be stored
#
# $use_rvm::                  If set to true, will install and configure RVM
#
# $rvm_ruby::                 The default Ruby version to use with RVM
#
# $initial_organization::     Initial organization to be created
#
# $initial_location::         Initial location to be created
#
# $admin_password::           Admin user password for Web application
#
# $enable_ostree::            Boolean to enable ostree plugin. This requires existence of an ostree install.
#
# $candlepin_event_queue::    The queue to use for candlepin
#
# $candlepin_qpid_exchange::  The exchange to use for candlepin
#
# $github_username::          Github username to add remotes for
#
# $use_ssh_fork::             If true, will use SSH to configure Github fork, otherwise HTTPS.
#
# $fork_remote_name::         Name of the remote that represents your fork
#
# $upstream_remote_name::     Name of the remove that represents the upstream repository
#
# $extra_plugins::            Array of Github namespace/repo plugins to setup and configure from git
#
class katello_devel (
  String $user = $katello_devel::params::user,
  Stdlib::Absolutepath $deployment_dir = $katello_devel::params::deployment_dir,
  String $oauth_key = $katello_devel::params::oauth_key,
  String $oauth_secret = $katello_devel::params::oauth_secret,
  String $post_sync_token = $katello_devel::params::post_sync_token,
  Boolean $use_passenger = $katello_devel::params::use_passenger,
  Enum['postgres', 'sqlite'] $db_type = $katello_devel::params::db_type,
  Stdlib::Absolutepath $mongodb_path = $katello_devel::params::mongodb_path,
  Boolean $use_rvm = $katello_devel::params::use_rvm,
  String $rvm_ruby = $katello_devel::params::rvm_ruby,
  String $initial_organization = $katello_devel::params::initial_organization,
  String $initial_location = $katello_devel::params::initial_location,
  String $admin_password = $katello_devel::params::admin_password,
  Boolean $enable_ostree = $katello::params::enable_ostree,
  String $candlepin_event_queue = $katello_devel::params::candlepin_event_queue,
  String $candlepin_qpid_exchange = $katello_devel::params::candlepin_qpid_exchange,
  String $github_username = $katello_devel::params::github_username,
  Boolean $use_ssh_fork = $katello_devel::params::use_ssh_fork,
  Optional[String] $fork_remote_name = $katello_devel::params::fork_remote_name,
  String $upstream_remote_name = $katello_devel::params::upstream_remote_name,
  Array[String] $extra_plugins = $katello_devel::params::extra_plugins,
) inherits katello_devel::params {

  $fork_remote_name_real = pick($fork_remote_name, $github_username)

  $group = $user

  $changeme = '$6$lb06/IMy$nZhR3LkR2tUunTQm68INFWMyb/8VA2vfYq0/fRzLoKSfuri.vvtjeLJf9V.wuHzw92.aw8NgUlJchMy/qK25x.'

  user { $katello_devel::user:
    ensure     => present,
    managehome => true,
    password   => $changeme,
  } ~>
  group { $katello_devel::group:
    ensure => present,
  }

  $candlepin_ca_cert = $::certs::ca_cert
  $pulp_ca_cert = $::certs::ca_cert

  Class['certs'] ~>
  class { '::certs::apache': } ~>
  class { '::katello_devel::apache': } ~>
  class { '::certs::qpid':
    require => Class['qpid::install'],
  } ~>
  class { '::qpid':
    ssl                    => true,
    ssl_cert_db            => $::certs::nss_db_dir,
    ssl_cert_password_file => $::certs::qpid::nss_db_password_file,
    ssl_cert_name          => 'broker',
  } ~>
  class { '::katello_devel::install': } ~>
  class { '::katello_devel::config': } ~>
  class { '::katello_devel::database': } ~>
  class { '::katello_devel::foreman_certs': } ~>
  class { '::katello_devel::setup':
    require => [
      Class['pulp'],
      Class['candlepin'],
    ],
  }


  Class['certs'] ~>
  Class['certs::qpid'] ~>
  class { '::certs::candlepin': } ~>
  class { '::candlepin':
    user_groups                  => $katello_devel::group,
    oauth_key                    => $katello_devel::oauth_key,
    oauth_secret                 => $katello_devel::oauth_secret,
    deployment_url               => 'katello',
    ca_key                       => $certs::ca_key,
    ca_cert                      => $certs::ca_cert_stripped,
    keystore_password            => $::certs::candlepin::keystore_password,
    truststore_password          => $::certs::candlepin::keystore_password,
    enable_basic_auth            => false,
    consumer_system_name_pattern => '.+',
    adapter_module               => 'org.candlepin.katello.KatelloModule',
    amq_enable                   => true,
    amqp_keystore_password       => $::certs::candlepin::keystore_password,
    amqp_truststore_password     => $::certs::candlepin::keystore_password,
    amqp_keystore                => $::certs::candlepin::amqp_keystore,
    amqp_truststore              => $::certs::candlepin::amqp_truststore,
    require                      => Class['katello_devel::database'],
    qpid_ssl_cert                => $::certs::qpid::client_cert,
    qpid_ssl_key                 => $::certs::qpid::client_key,
  }

  Class['certs'] ~>
  Class['certs::qpid'] ~>
  class { '::certs::pulp_client': } ~>
  class { '::certs::qpid_client': } ~>
  class { '::pulp':
    oauth_enabled          => true,
    oauth_key              => $katello_devel::oauth_key,
    oauth_secret           => $katello_devel::oauth_secret,
    messaging_url          => 'ssl://localhost:5671',
    messaging_ca_cert      => $certs::ca_cert,
    messaging_client_cert  => $certs::qpid_client::messaging_client_cert,
    messaging_transport    => 'qpid',
    messaging_auth_enabled => false,
    broker_url             => 'qpid://localhost:5671',
    broker_use_ssl         => true,
    consumers_crl          => $candlepin::crl_file,
    manage_broker          => false,
    manage_httpd           => false,
    manage_squid           => true,
    enable_rpm             => true,
    enable_puppet          => true,
    enable_docker          => true,
    enable_parent_node     => false,
    default_password       => 'admin',
    repo_auth              => true,
    enable_ostree          => $enable_ostree,
  } ~>
  class { '::qpid::client':
    ssl                    => true,
    ssl_cert_name          => 'broker',
    ssl_cert_db            => $certs::nss_db_dir,
    ssl_cert_password_file => $certs::qpid::nss_db_password_file,
  } ~>
  class { '::katello::qpid':
    client_cert             => $certs::qpid::client_cert,
    client_key              => $certs::qpid::client_key,
    katello_user            => $user,
    candlepin_event_queue   => $candlepin_event_queue,
    candlepin_qpid_exchange => $candlepin_qpid_exchange,
  }

  file { '/usr/local/bin/ktest':
    ensure  => file,
    content => template('katello_devel/ktest.sh.erb'),
    owner   => $user,
    group   => $group,
    mode    => '0755',
  }
}
