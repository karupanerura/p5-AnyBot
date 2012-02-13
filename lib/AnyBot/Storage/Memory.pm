package AnyBot::Storage::Memory;
use strict;
use warnings;
use utf8;

use 5.10.0;

use Class::Accessor::Lite (
    new => 1
);
use Data::Validator;

sub storage {
    my $self = shift;

    $self->{_storage} ||= +{};
}

sub set {
    state $rule = Data::Validator->new(
        name  => +{ isa => 'Str' },
        value => +{ isa => 'Defined' }
    )->with(qw/Method Sequenced/);
    my($self, $arg) = $rule->validate(@_);

    $self->storage->{$arg->{name}} = $arg->{value};
}

sub get {
    state $rule = Data::Validator->new(
        name => +{ isa => 'Str' },
    )->with(qw/Method Sequenced/);
    my($self, $arg) = $rule->validate(@_);

    return unless exists $self->storage->{$arg->{name}};

    return $self->storage->{$arg->{name}};
}

sub remove {
    state $rule = Data::Validator->new(
        name => +{ isa => 'Str' },
    )->with(qw/Method Sequenced/);
    my($self, $arg) = $rule->validate(@_);

    delete $self->storage->{$arg->{name}} if exists $self->storage->{$arg->{name}};
}

1;
