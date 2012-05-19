package Plack::Middleware::CombineStatic;

use parent 'Plack::Middleware';

use strict;
use warnings;
use Plack::Util::Accessor qw(minify parameter root cache path);
use Plack::Request;
use Plack::MIME;
use Perl6::Slurp;
use Class::Load;
use Digest::MD5 'md5_base64';
use Try::Tiny;

our $VERSION = '0.2';

our %minifiers = (
    'javascript' => 'JavaScript::Minifier::XS',
    'css'        => 'CSS::Minifier::XS',
);

=head1 NAME Plack::Middleware::CombineStatic


=head1 SYNOPSIS

    use Plack::Builder;
    use Plack;:Middleware::CombineStatic;

    my $app = sub { ... };

    my $cache = Some::Cache->new();

    builder {
        enable 'Plack::Middleware::CombineStatic',
            root => '/var/www/',
            parameter => 'filez',
            cache  => $cache,
            minify => 1;

        $app;
    };


    # in the browser
    GET http://localhost:5000/?filez=one.js,two.js,three.js
    
    # or 
    GET http://localhost:5000/?filez=three.js,two.js,five.js

    # etc.
=cut

sub call {
    my $self = shift;
    my $env  = shift;

    my $request = Plack::Request->new($env);

    my $ret = try {

        my ( $content_type, $content );
        if ( my $cached = $self->_get_from_cache($request) ) {
            ( $content_type, $content ) = @$cached;
        }
        else {

            my @files = split /,/, ( $request->param( $self->parameter ) || '' );

            return unless @files;
            return if grep { $_ !~ /$self->path/ } @files;

            my $root =
              ref $self->root eq 'ARRAY' ? $self->root : [ $self->root ];

            my @paths;
            for my $file ( @files ) {
                push @paths, map { join '/', $_, $file } @$root;
            }

            my @paths = grep { $_ if -e } @paths;

            ( $content_type, $content ) = $self->_slurp(@paths);

            $content = $self->_minify( $content_type, $content );
            $self->_set_in_cache( $request, [ $content_type, $content ] );

        }

        if ($content) {

            return [
                200,
                [
                    'Content-Length' => length($content),
                    'Content-Type'   => $content_type,
                ],
                [$content],
            ];
        }
    }
    catch {
        return $self->_fault;
    };

    return $ret if $ret;

    return $self->app->($env);
}

sub _fault {

    my $fault_message = '[FAILED TO LOAD STATIC RESOURCE]';
    return [
        500,
        [
            'Content-Length' => length($fault_message),
            'Content-Type'   => 'text/plain',
        ],
        [$fault_message],
    ];
}

sub _slurp {
    my $self = shift;

    my ( $content_type, $content );

    for my $file (@_) {
        $content_type ||= Plack::MIME->mime_type($file);

        die "mixing different file types isn't allowed"
          if $content_type ne Plack::MIME->mime_type($file);

        $content .= slurp $file;
    }

    return $content_type, $content;

}

sub _minify {
    my $self = shift;
    my ( $content_type, $content ) = @_;

    return $content unless $self->minify();

    my $type = $content_type =~ /javascript/ ? 'javascript' : 'css';

    Class::Load::load_class( $minifiers{$type} );

    if ( $type eq 'javascript' ) {
        return JavaScript::Minifier::XS::minify($content);
    }
    else {
        return CSS::Minifier::XS::minify($content);
    }
}

sub _get_from_cache {
    my ( $self, $request ) = @_;

    return unless $self->cache;

    my $cache_key = md5_base64( $request->param( $self->parameter ) );
    return $self->cache->get($cache_key);
}

sub _set_in_cache {
    my ( $self, $request, $data ) = @_;

    return unless $self->cache;

    my $cache_key = md5_base64( $request->param( $self->parameter ) );
    return $self->cache->set( $cache_key, $data );
}

=head1 SEE ALSO

L<Plack::Middleware::Static|Plack::Middleware::Static>

L<Plack::Middleware::Static::Minifier|Plack::Middleware::Static::Minifier>

L<Plack::Middleware::Assets|Plack::Middleware::Assets>



=head1 AUTHOR

tjmc

=cut

1;
