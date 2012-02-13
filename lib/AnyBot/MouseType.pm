package AnyBot::MouseType;
use strict;
use warnings;
use utf8;

use parent qw/Exporter/;

my $PREFIX = __PACKAGE__ . '::';

our @EXPORT_OK = qw/local_type/;
sub local_type {
    my($type, $inner) = @_;

    my $local_type = $PREFIX . $type;
    return $inner ? "${inner}[${local_type}]" : $local_type;
}

use Mouse::Util::TypeConstraints;

subtype local_type('UInt')
    => as 'Int'
    => where { $_ > 0 };

subtype local_type('Storage')
    => as 'Object'
    => where { $_->can('get') and $_->can('set') and $_->can('remove') };

enum local_type('Command') => qw/
    JOIN
    PART
    NICK
    TOPIC
    NOTICE
    PRIVMSG
/;

no Mouse::Util::TypeConstraints;
1;
