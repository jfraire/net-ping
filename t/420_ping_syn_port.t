# Same as 400_ping_sync.t, but port should be included in return
use strict;

BEGIN {
  if ($ENV{PERL_CORE}) {
    unless ($ENV{PERL_TEST_Net_Ping}) {
      print "1..0 # Skip: network dependent test\n";
        exit;
    }
  }
  unless (eval "require Socket") {
    print "1..0 \# Skip: no Socket\n";
    exit;
  }
  unless (getservbyname('echo', 'tcp')) {
    print "1..0 \# Skip: no echo port\n";
    exit;
  }
  unless (getservbyname('http', 'tcp')) {
    print "1..0 \# Skip: no http port\n";
    exit;
  }
}

# Remote network test using syn protocol.
#
# NOTE:
#   Network connectivity will be required for all tests to pass.
#   Firewalls may also cause some tests to fail, so test it
#   on a clear network.  If you know you do not have a direct
#   connection to remote networks, but you still want the tests
#   to pass, use the following:
#
# $ PERL_CORE=1 make test

# Try a few remote servers
my %webs;
my @hosts = (
  # Hopefully this is never a routeable host
  "172.29.249.249",

  # Hopefully all these web and smtp ports are open
  "www.google.com",
  "www.bluehost.com",
  "yahoo.com",
  "www.yahoo.com",
  "www.duckduckgo.com",
  "www.microsoft.com",
  "www.about.com",
);

use Test::More tests =>33;

BEGIN {use_ok('Net::Ping')};

my $can_alarm = eval {alarm 0; 1;};

sub Alarm {
    alarm(shift) if $can_alarm;
}

Alarm(50);
$SIG{ALRM} = sub {
    fail('Alarm timed out');
    die "TIMED OUT!";
};

my $p = Net::Ping->new("syn", 10);

isa_ok($p, 'Net::Ping', 'new() worked');

# Change to use the more common web port.
# (Make sure getservbyname works in scalar context.)
# cmp_ok(($p->{port_num} = getservbyname("http", "tcp")), '>', 0, 'valid port');

my %contacted;
foreach my $host (@hosts) {
    # ping() does dns resolution and
    # only sends the SYN at this point
    Alarm(50); # (Plenty for a DNS lookup)
    foreach my $port (80, 443) {
        $p->port_number($port);
        is($p->ping($host), 1, "Sent SYN to $host at port $port [" . ($p->{bad}->{$host} || "") . "]");
        $contacted{"$host:$port"} = 1;
    }
}

Alarm(20);
while (my @r = $p->ack()) {
    my %res;
    @res{qw(host ack_time ip port)} = @r;
    my $answered = "$res{host}:$res{port}";
    like($answered, qr/^[\w\.]+:\d+$/, "Supposed to be up: $res{host}:$res{port}");
    delete $contacted{$answered};
}

Alarm(0);
# 172.29.249.249 should not be reachable, and about.com does not support
# https
is keys %contacted, 3,
    'Three servers did not acknowledge our ping';
delete $contacted{$_} 
    foreach ('172.29.249.249:80','172.29.249.249:443', 'www.about.com:443');
is keys %contacted, 0,
    'The servers taht did not acknowledge our ping were correct';

done_testing();
