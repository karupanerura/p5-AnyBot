package AnyBot;
use 5.008_001;
use strict;
use warnings;

our $VERSION = '0.01';

use Class::Accessor::Lite (
    ro => [qw/client/]
);

1;
__END__

=head1 NAME

AnyBot - Perl extention to do something

=head1 VERSION

This document describes AnyBot version 0.01.

=head1 SYNOPSIS

    # bot.pl
    use AnyBot;

    my $irc_bot = AnyBot->new(
        IRC => +{
            nick => 'echo_bot',
            host => 'localhost',
            port => 6667,
        },
    );
    $bot->load_module(qw/MyProj::Echo MyProj::Karma/);

    my $twitter_bot = AnyBot->new(
        Twitter => +{
            access_token  => 'XXXXXX',
            access_secret => 'XXXXXX',
        },
    );
    $twitter_bot->load_module(qw/MyProj::Echo/);

    AnyBot->register($irc_bot, $twitter_bot);
    AnyBot->run;

    # lib/MyProj/Echo.pm
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

    # lib/MyProj/Karma.pm
    use AnyBot::Module;

    regexp qr{^([-_a-zA-Z0-9]+)(-{2}|+{2})$} => sub {
        my($client, $receive) = @_;

        my $user = $1;
        my $incr = ($2 eq '++') ? 1 : 0;

        my $key   = 'karma_' . $user;
        my $karma = $client->storage->get($key);
        $client->storage->set($key => $incr ? ++$karma : --$karma);

        $client->send_channel(
            $receive->{attribute}{channel},
            "${user}: $karma"
        );
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
