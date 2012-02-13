package AnyBot::Module;
use 5.010_001;
use strict;
use warnings;
use utf8;

our $VERSION = '0.01';

use Carp ();

use AnyBot::Event::Any;
use AnyBot::Event::Regexp;

use Data::Validator;
use Class::Accessor::Lite (
    rw  => [qw/event/],
    new => 1
);

sub import {
    my $class  = shift;
    my $caller = caller;

    strict->import;
    warnings->import;
    utf8->import;

    {
        no strict 'refs';
        unshift @{"${caller}::ISA"} => $class;
    }
    my $instance = $caller->new->init;

    my %export = (
        any      => $instance->_any,
        regexp   => $instance->_regexp,
        instance => sub { $instance },
    );
    foreach my $name (keys %export) {
        my $code = $export{$name};

        {
            no strict 'refs';
            *{"${caller}::${name}"} = $code;
        }
    }
}

sub _any {
    my $self = shift;

    return sub (&) {## no critic
        $self->add_event(
            do {
                local $Carp::CarpLevel = $Carp::CarpLevel + 1;
                AnyBot::Event::Any->new(@_);
            }
        );
    }
}

sub _regexp {## no critic
    my $self = shift;

    return sub ($&) {## no critic
        $self->add_event(
            do {
                local $Carp::CarpLevel = $Carp::CarpLevel + 1;
                AnyBot::Event::Regexp->new(@_);
            }
        );
    }
}

sub init {
    my $self = shift;

    $self->event([]);

    return $self;
}

sub add_event {
    state $rule = Data::Validator->new(
        event => +{ isa => 'AnyBot::Event' }
    )->with(qw/Method Sequenced/);
    my($self, $args) = $rule->validate(@_);

    push @{ $self->event } => $args->{event};
}

1;
__END__

=head1 NAME

AnyBot::Module - Perl extention to do something

=head1 VERSION

This document describes AnyBot::Module version 0.01.

=head1 SYNOPSIS

    use AnyBot::Module;

    any {
        my($client, $receive) = @_;

        if ($receive->{attribute}{type} eq 'IRC') {
            $client->send_channel(
                $receive->{attribute}{channel},
                $receive->{message}
            );
        }
        elsif ($receive->{attribute}{type} eq 'Twitter') {
            $client->post($receive->{message});
        }
    };

    1;

=head1 DESCRIPTION

# TODO

=head1 INTERFACE

=head2 Functions

=head3 C<< hello() >>

# TODO

=head1 DEPENDENCIES

Perl 5.8.1 or later.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 SEE ALSO

L<perl>

=head1 AUTHOR

Kenta Sato E<lt>karupa@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012, Kenta Sato. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
