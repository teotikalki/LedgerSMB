#!/usr/bin/plackup

BEGIN {
 if ( $ENV{'LSMB_WORKINGDIR'} && -f "$ENV{'LSMB_WORKINGDIR'}/lib/LedgerSMB.pm" ) { chdir $ENV{'LSMB_WORKINGDIR'}; }
}

package LedgerSMB::FCGI;

use lib 'lib';
use CGI::Emulate::PSGI;
use LedgerSMB::PSGI;
use LedgerSMB::Sysconfig;
use Plack::Builder;
use Plack::App::File;
# Optimization
use Plack::Middleware::ConditionalGET;
use Plack::Builder::Conditionals;

require Plack::Middleware::Pod if ( $ENV{PLACK_ENV} && $ENV{PLACK_ENV} eq 'development' );

die 'Cannot verify version of libraries, may be including out of date modules?' unless $LedgerSMB::PSGI::VERSION == '1.5';

# # Lets report to the console what type of dojo we are running with
if ( $LedgerSMB::Sysconfig::dojo_built) {
    print "Starting Worker on PID $$ Using Built Dojo\n";
} else {
    print "Starting Worker on PID $$ Using Dojo Source\n";
}

my $old_app = LedgerSMB::PSGI::old_app();
my $new_app = LedgerSMB::PSGI::new_app();

builder {
    enable match_if path(qr!.+\.(css|js|png|ico|jp(e)?g|gif)$!),
        'ConditionalGET';

    enable 'Plack::Middleware::Pod',
        path => qr{^/pod/},
        root => './',
        pod_view => 'Pod::POM::View::HTMl' # the default
    if $ENV{PLACK_ENV} =~ "development";

    mount '/rest/' => LedgerSMB::PSGI::rest_app();

    # not using @LedgerSMB::Sysconfig::scripts: it has not only entry-points
    mount "/$_" => $old_app
        for ('aa.pl', 'am.pl', 'ap.pl',
             'ar.pl', 'gl.pl', 'ic.pl', 'ir.pl',
             'is.pl', 'oe.pl', 'pe.pl');

    mount "/$_" => $new_app
        for  (@LedgerSMB::Sysconfig::newscripts);

    mount '/stop.pl' => sub { exit; }
        if $ENV{COVERAGE};

    mount '/' => Plack::App::File->new( root => 'UI' )->to_app;
};

# -*- perl-mode -*-
