package AnyBot::Utils;
use strict;
use warnings;
use utf8;

use parent qw/Exporter/;
our @EXPORT_OK = qw/do_or_enqueue/;

use 5.10.0;

use Data::Validator;

my $LAST_RUN_TIME = 0;
my @SEND_QUEUE;
my $SEND_TIMER;
sub do_or_enqueue {
    state $rule = Data::Validator->new(
        code => +{ isa => 'CodeRef' },
        args => +{ isa => 'HashRef', optional => 1 }
    );
    my($self, $arg) = $rule->validate(@_);

    
}

sub _run {
    my($self, $cb) = @_;
    if (scalar(@SEND_QUEUE) >= $self->{config}{wait_queue_size}) {
        return;
    }
    if (time() - $LAST_SEND_TIME <= 0 || $SEND_TIMER) {
        $SEND_TIMER ||= AnyEvent->timer(
            after    => 1,
            interval => $self->{config}{interval},
            cb       => sub {
                (shift @SEND_QUEUE)->();
                $LAST_SEND_TIME = time();
                $SEND_TIMER = undef unless @SEND_QUEUE;
            },
            );
        push @SEND_QUEUE, $cb;
        return;
    }
    $cb->();
    $LAST_SEND_TIME = time();
}


1;
