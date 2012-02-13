package AnyBot::Client::IRC;
use 5.010_000;
use strict;
use warnings;
use utf8;

use AnyEvent::IRC::Client;
use Carp ();
use Encode ();
use String::CamelCase ();
use Class::Load;
use Log::Minimal;
use List::MoreUtils qw/any/;
use Scalar::Util qw/weaken/;

our $VERSION    = '0.01';
our $ROOT_CLASS = 'AnyBot';

use Class::Accessor::Lite (
    ro => [qw/host port encoding nick recive_commands interval/],
    rw => [qw/channel encoder event client/],
);
use AnyBot::MouseType qw/local_type/;
use AnyBot::Storage::Memory;

sub new {
    state $rule = Data::Validator->new(
        nick            => +{ isa => 'Str' },
        host            => +{ isa => 'Str' },
        port            => +{ isa => local_type('UInt'), default => 6667 },
        password        => +{ isa => 'Str',              optinal => 1 },
        encoding        => +{ isa => 'Str',              default => 'utf-8' },
        interval        => +{ isa => local_type('UInt'), default => 1 },
        recive_commands => +{ isa => local_type('Command' => 'ArrayRef'), default => sub { [qw/NOTICE/] } },
        storage         => +{ isa => local_type('Storage'), default => sub { AnyBot::Storage::Memory->new } },
    )->with(qw/Method/);
    my($class, $arg) = $rule->validate(@_);

    my $self = bless(+{
        nick        => $arg->{nick},
        host            => $arg->{host},
        port            => $arg->{port},
        encoding        => $arg->{encoding},
        interval        => $arg->{interval},
        recive_commands => $arg->{recive_commands},
    } => $class)->init;

    # create client
    $self->client(
        $self->create_client(
            $self->host, $self->port,
            {
                nick => $self->nick,
                exists($arg->{password}) ? (
                    password => $arg->{password}
                ) : (),
            }
        )
    );

    return $self;
}

sub init {
    my $self = shift;

    $self->channel(+{});
    $self->event([]);
    $self->encoder( Encode::find_encoding($self->encoding) );

    return $self;
}

sub create_client {
    my($self, @connect_info) = @_;

    my $con = AnyEvent::IRC::Client->new;
    $con->reg_cb(
        connect => sub {
            my ($con, $err) = @_;
            if (defined $err) {
                critf('connect error: %s', $err);
                return;
            }
        }
    );

    weaken($self);
    $con->reg_cb (
        'irc_*' => sub {
            my(undef, $param) = @_;
            return if $param->{command} =~ /\A[0-9]+\z/;

            my $command = uc($param->{command});
            return unless any { $_ eq $command } @{ $self->recive_commands };

            my($channel, $message) = @{ $param->{params} };
            my($nick, ) = split '!', ($param->{prefix} || '');

            # decode
            $channel  = $self->encoder->decode($channel);
            $message  = $self->encoder->decode($message);
            $nick     = $self->encoder->decode($nick);

            my %receive_info = (
                message   => $message,
                nick      => $nick,
                attribute => +{
                    channel  => $channel,
                    type     => 'IRC',
                }
            );
            foreach my $event (@{ $self->event }) {
                if ( $event->is_want(\%receive_info) ) {
                    $event->run(\%receive_info);
                }
            }
        }
    );
    $con->connect(@connect_info);

    return $con;
}

sub add_event {
    state $rule = Data::Validator->new(
        type  => +{ isa => 'Str', xor => [qw/class/] },
        class => +{ isa => 'Str', xor => [qw/type/]  },
        args  => +{ isa => 'HashRef' },
    )->with(qw/Method/);
    my($self, $arg) = $rule->validate(@_);
    my $event_class = exists($arg->{class}) ?
        $arg->{class}:
        "${ROOT_CLASS}::Event::@{[ String::CamelCase::camelize($arg->{type}) ]}";

    Class::Load::load_class($class);
    push @{ $self->event } => $event_class->new($arg->args);
}

sub send_channel {
    state $rule = Data::Validator->new(
        channel => +{ isa => 'Str' },
        message => +{ isa => 'Str' },
        privmsg => +{ isa => 'Bool', optinal => 1 }
    )->with(qw/Method Sequenced/);
    my($self, $arg) = $rule->validate(@_);

    my $type    = (exists($arg->{privmsg}) and $arg->{privmsg}) ? 'PRIVMSG' : 'NOTICE';
    my $channel = $self->encoder->encode($arg->{channel});
    my $message = $self->encoder->encode($arg->{message});

    $self->do_or_enqueue(
        code => sub {
            my($self, $type, $channel, $message) = @_;
            $self->client->send_chan(
                $channel,
                $type,
                $channel,
                $message,
             );
        },
        args => [$type, $channel, $message],
    );
}

sub send_user {
    state $rule = Data::Validator->new(
        user    => +{ isa => 'Str' },
        message => +{ isa => 'Str' },
        privmsg => +{ isa => 'Bool', optinal => 1 }
    )->with(qw/Method Sequenced/);
    my($self, $arg) = $rule->validate(@_);

    my $type    = (exists($arg->{privmsg}) and $arg->{privmsg}) ? 'PRIVMSG' : 'NOTICE';
    my $user    = $self->encoder->encode($arg->{user});
    my $message = $self->encoder->encode($arg->{message});

    $self->do_or_enqueue(
        code => sub {
            my($self, $type, $user, $message) = @_;
            $self->client->send_srv($type => $user, $message);
        },
        args => [$type, $user, $message],
    );
}

sub join_channels {
    my($self, @channels) = @_;

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;
    foreach my $channel (@channels) {
        if (not(ref $channel)) {
            $self->join_channel($channel);
        }
        elsif (ref $channel eq 'HASH') {
            $self->join_channel(%$channel);
        }
        elsif (ref $channel eq 'ARRAY') {
            $self->join_channel(@$channel);
        }
        else {
            Carp::croak('Not valid argument type.');
        }
    }
}

sub join_channel {
    state $rule = Data::Validator->new(
        channel  => +{ isa => 'Str' },
        password => +{ isa => 'Str', optional => 1 }.
    )->with(qw/Method Sequenced/);
    my($self, $arg) = $rule->validate(@_);

    $self->channel->{ $arg->{channel} } = exists($arg->{passrowd}) ?
        +{ password => $arg->{passrowd} } :
        +{};

    my $channel             = $self->encoder->encode($arg->{channel});
    my $password; $password = $self->encoder->encode($arg->{passrowd}) if exists($arg->{passrowd});

    $self->do_or_enqueue(
        code => sub {
            my($self, $channel, $password) = @_;
            $self->client->send_srv(JOIN => $channel, $password ? ($password) : ());
        },
        args => [$channel, $password]
    );
}

sub leave_channels {
    my($self, @channels) = @_;

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;
    foreach my $channel (@channels) {
        $self->leave_channel($channel);
    }
}

sub leave_channel {
    state $rule = Data::Validator->new(
        channel  => +{ isa => 'Str' },
    )->with(qw/Method Sequenced/);
    my($self, $arg) = $rule->validate(@_);

    delete $self->channel->{ $arg->{channel} };

    my $channel  = $self->encoder->encode($arg->{channel});

    $self->do_or_enqueue(
        code => sub {
            $self->client->send_srv(PART => $channel);
        },
        args => [$channel]
    );
}

sub do_or_enqueue {
    state $rule = Data::Validator->new(
        code => +{ isa => 'CodeRef' },
        args => +{ isa => 'HashRef', optional => 1 }
    )->with(qw/Method/);
    my($self, $arg) = $rule->validate(@_);

    my @args = $arg->{args};
    
}

1;
__END__

=head1 NAME

AnyBot::Client::IRC - Perl extention to do something

=head1 VERSION

This document describes AnyBot::Client::IRC version 0.01.

=head1 SYNOPSIS

    use AnyEvent;
    use AnyBot::Client::IRC;

    my $bot = AnyBot::Client::IRC->new(
        host     => 'localhost',
        port     => 6667,
        password => 'server_password',
        encoding => 'iso-2022-jp', # default is utf-8
        nick     => 'hoge_bot',
        recive_commands => [qw/PRIVMSG NOTICE/], # default is [ 'PRIVMSG' ]
    );
    $bot->join_channels(qw/#hoge #fuga/, +{ '#foo' => 'password' });

    my $cv = AnyEvent->condvar;
    $bot->add_event(# echo
        type => 'any',
        args => +{
            cb => sub {
                my($bot, $channel, $message) = @_;
                $bot->send_channel($channel => $message, 'PRIVMSG');
            },
        },
    );

    my %command = (
        join => sub {
            my($client, $channel, $message, $join_to) = @_;
            $bot->join_channel($join_to);
        },
        leave => sub {
            my($bot, $channel, $message, $leave_from) = @_;
            $bot->leave_channel($leave_from);
        },
        exit => sub { $cv->send }
    );
    $bot->add_event(# run command
        type => 'regexp',
        args => +{
            regexp => qr{^!([^\s]+)\s(.+)$},
            cb     => sub {
                my($bot, $channel, $message) = @_;
                if (exists $command{$1}) {
                    my $cmd  = $command{$1};
                    my @args = $2 ? split(/\s/, $2) : ();
                    $cmd->($bot, $channel, $message, @args);
                }
            },
        },
    );
    $bot->run;

    $cv->recv;

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
