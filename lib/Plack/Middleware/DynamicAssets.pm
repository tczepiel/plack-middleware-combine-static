package Plack::Middleware::DynamicAssets;


use parent 'Plack::Middleware';

use strict;
use warnings;
use Plack::Util::Accessor qw(minify parameter root);
use Plack::Request;
use Plack::MIME;
use Perl6::Slurp;
use Class::Load;
use Try::Tiny;

our $VERSION = '0.1';

our %minifiers = (
    'javascript' => 'JavaScript::Minifier::XS',
    'css'        => 'CSS::Minifier::XS',
);

=head1 NAME Plack::Middleware::DynamicAssets


=head1 SYNOPSIS

    use Plack::Builder;
    use Plack;:Middleware::DynamicAssets;

    my $app = sub { ... };

    builder {
        enable 'Plack::Middleware::DynamicAssets',
            root => '/var/www/',
            parameter => 'filez',
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
        my @files = split /,/, $request->param( $self->parameter );
        my @paths = map { join '/', $self->root, $_ } @files;

        my ( $content_type, $content ) = $self->_slurp(@paths);

        if ($content) {

            $content = $self->_minify( $content_type, $content )
              if $self->minify;

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
        [ $fault_message ],
    ];
}

sub _slurp {
    my $self = shift;

    my ( $content_type, $content );
    for (@_) {
        $content_type ||= Plack::MIME->mime_type($_);
        $content .= slurp;
    }

    return $content_type, $content;

}

sub _minify {
    my $self = shift;
    my ( $content_type, $content ) = @_;

    my $type = $content_type =~ /javascript/ ? 'javascript' : 'css';

    Class::Load::load_class($minifiers{$type});

    if ( $type eq 'javascript' ) {
        return JavaScript::Minifier::XS::minify($content);
    }
    else {
        return CSS::Minifier::XS::minify($content);
    }
}


=head1 SEE ALSO

L<Plack::Middleware::Static|Plack::Middleware::Static>

L<Plack::Middleware::Static::Minifier|Plack::Middleware::Static::Minifier>

L<Plack::Middleware::Assets|Plack::Middleware::Assets>



=head1 AUTHOR

tjmc

=cut

1;
