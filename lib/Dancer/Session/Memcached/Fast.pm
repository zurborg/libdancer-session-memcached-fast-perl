use strict;
use warnings;

package Dancer::Session::Memcached::Fast;

# ABSTRACT: Cache::Memcached::Fast based session backend for Dancer

# VERSION

use mro;
use Carp;
use Cache::Memcached::Fast;
use CBOR::XS qw(encode_cbor decode_cbor);
use Dancer::Config 'setting';
use parent 'Dancer::Session::Abstract';

my $MCF;

sub init {
    my $self = shift;

    $self->next::method(@_);

    my $servers = setting("session_memcached_servers");
    croak "The setting session_memcached_servers must be defined"
      unless defined $servers;

    $servers = [ split /,/, $servers ];

    my $namespace = setting("session_memcached_namespace") || __PACKAGE__;

    $MCF = Cache::Memcached::Fast->new(
        {
            servers    => $servers,
            namespace  => $namespace,
            check_args => '',
        }
    );

    return $self;
}

sub _freeze {
    encode_cbor shift;
}

sub _thaw {
    bless decode_cbor(pop) => shift;
}

=for Pod::Coverage TO_CBOR

=cut

sub TO_CBOR {
    +{ ( %{ shift() } ) };
}

sub _store {
    my ($self) = @_;
    $MCF->set( $self->id => $self->_freeze );
    $self;
}

sub create {
    my ($class) = @_;
    my $self = $class->new;
    $self->_store;
    $self;
}

sub retrieve {
    my ( $class, $id ) = @_;
    my $cbor = $MCF->get($id);
    return unless defined $cbor;
    $class->_thaw($cbor);
}

sub get_value {
    my ( $self, $key ) = @_;
    $self->{$key};
}

sub set_value {
    my ( $self, $key, $value ) = @_;
    $self->{$key} = $value;
}

sub destroy {
    my ($self) = @_;
    $MCF->delete( $self->id );
    undef;
}

sub flush {
    my $self = shift;
    $self->_store;
    $self;
}

1;
