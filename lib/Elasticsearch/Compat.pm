package Elasticsearch::Compat;

use Moo;
use Elasticsearch 0.73;

use Scalar::Util qw(openhandle);
use Elasticsearch::Util qw(parse_params);
use namespace::clean;

our $VERSION = '0.01';

#===================================
sub new {
#===================================
    my ( $class, $orig ) = parse_params(@_);
    my %params = (
        nodes           => delete $orig->{servers},
        request_timeout => delete $orig->{timeout},
        cxn_pool        => delete $orig->{no_refresh} ? 'Static' : 'Sniff',
        client          => 'Compat',
        deflate            => delete $orig->{deflate}            || 0,
        max_content_length => delete $orig->{max_content_length} || 0
    );

    # transport
    my $transport = delete $orig->{transport} || 'http';
    if ( $transport =~ /^(aehttp|aecurl|thrift)/ ) {
        die "Transport <$transport> is not supported";
    }
    if ( $transport eq 'httplite' ) {
        warn "Transport <httplite> is not supported. Using <httptiny>";
    }
    $params{cxn} = $transport eq 'http' ? 'LWP' : 'HTTPTiny';

    # trace_calls
    if ( my $trace = delete $orig->{trace_calls} ) {
        $params{trace_to}
            = $trace eq '1' ? 'Stderr'
            : !ref $trace        ? [ 'File',       $trace ]
            : openhandle($trace) ? [ 'FileHandle', $trace ]
            : ref($trace) eq 'CODE' ? [ 'Callback', { logging_cb => $trace } ]
            :   die "Unrecognised value for <trace_requests>";
    }

    return Elasticsearch->new( %params, %$orig );
}

1;

__END__

# ABSTRACT: A compatibility layer for migrating from ElasticSearch.pm

=head1 DESCRIPTION

With the release of the official new L<Elasticsearch> module, the old
L<ElasticSearch> (note the change in case) module has been deprecated. This module,
L<Elasticsearch::Compat> is a compatibility layer to help migrate
existing code from the old module to the new.

The client interface (ie L</new()> plus all request methods like
L<search()|Elasticsearch::Client::Compat/search()>) are completely compatible
with the old Elasticsearch.pm. The L</new()> method translates the parameters
accepted by the old module to the parameters accepted by the new module. All
tests in the old test suite pass.

However, the networking layer has been replaced by the new L<Elasticsearch>
module. Currently the only available transport backends are C<http> (L<LWP>)
and C<httptiny> (L<HTTP::Tiny>).  Soon there will also be a L<Net::Curl>
backend.  The L<AnyEvent> backends are not supported. That may change in
the future.

No further development of this compatibility layer is planned.  It allows
you to use your old code without change (other than the module name), but
new code should use the new L<Elasticsearch> module.

To use this module, you will need to change:

    use ElasticSearch;
    my $e = ElasticSearch->new(...);

to

    use Elasticsearch::Compat;
    my $e = Elasticsearch::Compat->new(...);

You can use the official client in the same code as the compatibility
layer with:

    use Elasticsearch;
    use Elasticsearch::Compat;

    my $new_es = Elasticsearch->new(...);
    my $old_es = Elasticsearch::Compat->new(...);


=head1 Creating a new Elasticsearch::Compat instance

=head2 new()

    $es = Elasticsearch::Compat->new(
            transport    =>  'http',
            servers      =>  '127.0.0.1:9200'                   # single server
                              | ['es1.foo.com:9200',
                                 'es2.foo.com:9200'],           # multiple servers
            trace_calls  => 1 | '/path/to/log/file' | $fh
            timeout      => 30,

            no_refresh   => 0 | 1                               # don't retrieve the live
                                                                # server list. Instead, use
                                                                # just the servers specified
     );

The L</new()> method translates the parameters accepted by the old module into
parameters accepted by the new L<Elasticsearch> module, and
returns an L<Elasticsearch::Client::Compat> instance,
which provides the same methods as were available in the old L<ElasticSearch>
module.

=head3 servers

C<servers> can be either a single server or an ARRAY ref with a list of servers.
If not specified, then it defaults to C<localhost:9200>.

These servers are used in a round-robin fashion. If any server fails to
connect, then the other servers in the list are tried, and if any
succeeds, then a list of all servers/nodes currently known to the
Elasticsearch cluster are retrieved and stored.
This list of known nodes is refreshed automatically.

=head3 no_refresh

Retrieving the list of live nodes from the cluster may not be desirable behaviour
if, for instance, you are connecting to remote servers which use internal
IP addresses, or which don't allow remote C<nodes()> requests.

If you want to disable the sniffing behaviour, set C<no_refresh> to C<1>,
in which case the transport module will round robin through the
C<servers> list only. Failed nodes will be removed from the list
(but added back in later if they respond to a ping or when all nodes have failed).

=head3 Transport Backends

There are two C<transport> backends that Elasticsearch::Compat can use:
C<http> (the default, based on LWP) and C<httptiny> (based on L<HTTP::Tiny>).
The C<AnyEvent> based transports are not supported by Elasticsearch::Compat.

The C<httptiny> backend is faster than C<http>, but does not use persistent
connections. If you want to use it, make sure that your open filehandles limit
(C<ulimit -l>) is high, or your connections may hang because your system runs
out of sockets.

=cut

=head1 OTHER METHODS

See L<Elasticsearch::Client::Compat> for documenation of methods supported
by the client.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Elasticsearch::Compat

You can also look for information at:

=over 4

=item * GitHub

L<http://github.com/elasticsearch/elasticsearch-perl-compat>

=item * Search MetaCPAN

L<https://metacpan.org/module/Elasticsearch::Compat>

=item * IRC

The L<#elasticsearch|irc://irc.freenode.net/elasticsearch> channel on
C<irc.freenode.net>.

=item * Mailing list

The main L<Elasticsearch mailing list|http://www.elasticsearch.org/community/forum/>.

=back

=head1 TEST SUITE

The full test suite requires a live Elasticsearch cluster to run.  CPAN
testers doesn't support this.  You can see full test results here:
L<http://travis-ci.org/#!/clintongormley/Elasticsearch::Compat/builds>.

To run the full test suite locally, run it as:

    perl Makefile.PL
    ES_HOME=/path/to/elasticsearch make test

=cut

