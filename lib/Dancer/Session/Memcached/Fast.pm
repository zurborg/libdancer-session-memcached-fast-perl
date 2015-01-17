use strict;
use warnings;

package Dancer::Session::Memcached::Fast;

# ABSTRACT: Cache::Memcached::Fast based session backend for Dancer

# VERSION

use mro;
use Carp;
use Cache::Memcached::Fast;
use CBOR::XS qw(encode_cbor decode_cbor);
use Dancer::Config qw(setting);
use Dancer qw();
use parent 'Dancer::Session::Abstract';

sub init {
    my $self = shift;

    $self->next::method(@_);

    my $servers = setting("session_memcached_servers");
    croak "The setting session_memcached_servers must be defined"
      unless defined $servers;

    $servers = [ split /,/, $servers ];

    my $namespace = setting("session_memcached_namespace") || __PACKAGE__;

    $self->{cmf} = Cache::Memcached::Fast->new(
        {
            servers    => $servers,
            check_args => '',
        }
    );

    $self;
}

sub _engine {
    Dancer::engine('session');
}

sub _mkns {
    my $id = shift;
    my $ns = setting("session_memcached_namespace") || __PACKAGE__;
    return "$ns#$id";
}

sub _boot {
    my ( $class, %config ) = @_;
    my $engine = _engine;
    bless {
        id  => undef,
        cmf => $engine->{cmf},
        %config
    } => $class;
}

sub create {
    my ($class) = @_;
    my $self = $class->_boot( id => $class->build_id );
    $self->{cmf}->namespace( _mkns( $self->id ) );
    my $expire = 2**20;
	# TODO: use $expire from... session cookie?
    $self->{cmf}->set( '' => time, $expire );
    $self;
}

sub retrieve {
    my ( $class, $id ) = @_;
    my $self = $class->_boot( id => $id );
    $self->{cmf}->namespace( _mkns( $self->id ) );
    my $time = $self->{cmf}->get('');
    return unless defined $time and $time =~ m{^\d+$};
    $self;
}

sub get_value {
    my ( $self, $key ) = @_;
    my $value = $self->{cmf}->get($key);
    return unless defined $value;
    $value = decode_cbor $value;
    $value;
}

sub set_value {
    my ( $self, $key, $value ) = @_;
    $self->{cmf}->set( $key => encode_cbor $value);
}

sub destroy {
    my ($self) = @_;
    $self->{cmf}->flush_all;
    undef;
}

sub flush {
    my $self = shift;
    $self->{cmf}->nowait_push;
    $self;
}

1;
