#!/usr/bin/perl

use strict;
use warnings;

use File::Find;
use File::Spec;
use File::Spec::Unix;
use Cwd qw(abs_path);
use File::Path qw(make_path remove_tree);
use File::Basename qw/basename dirname/;
use File::Slurp;

use Pod::Simple::HTML;
use Encode qw(decode encode from_to);

$Pod::Simple::HTML::Content_decl = q{<meta charset="utf-8">};
$Pod::Simple::HTML::Doctype_decl = qq{<!DOCTYPE html>\n};

$Pod::Simple::HTML::Tagmap{"Verbatim"}  = "\n<pre><code>";
$Pod::Simple::HTML::Tagmap{"/Verbatim"} = "</code></pre>\n";
$Pod::Simple::HTML::Tagmap{"VerbatimFormatted"}  = "\n<pre><code>";
$Pod::Simple::HTML::Tagmap{"/VerbatimFormatted"} = "</code></pre>\n";


my @found;
my @pod_names;
my @dir_names;

print "chdir docs\n";
chdir "docs" or die $!;
find( sub { push @found, $File::Find::name; }, '.');

foreach my $name (@found) {

    if (-d $name) {
        next if $name eq ".";
        push @dir_names, $name;
    }
    else {
        next unless $name =~ /\.pod|\.pl$/i;
        push @pod_names, $name;
    }

}

chdir ".." or die $!;

foreach my $dir (@dir_names) {

    next if $dir =~ /Apocalypse|Exegesis|Magazine|man_pages/i;

    my $path = File::Spec->catdir("source", $dir);
    # remove_tree( $path, {verbose => 1} );
    make_path( $path, {verbose => 1} );
}

foreach my $pod (@pod_names) {

    next if $pod =~ /Apocalypse|Exegesis|Magazine|man_pages/i;

    if ($pod =~ /S26-documentation/) {
        print "Skip: S26-documentation.pod contains Perl 6 Pod.\n";
        next;
    }

    #my $p = Pod::Simple::HTML->new();
    my $p = My::Pod->new();
    # $p->complain_stderr(1);
    $p->index(1);
    $p->html_header_before_title(qq|$Pod::Simple::HTML::Doctype_decl<html lang="ja">\n<head>\n<title>|);
    $p->force_title( basename($pod, ".pod") );
    $p->strip_verbatim_indent(
        sub {
            my $lines = shift;
            s/^\s{4}// for @{$lines};
            return undef;
        }
    );
    $p->html_javascript(q|<script src="http://yandex.st/highlightjs/8.0/highlight.min.js"></script>
<script>hljs.configure( { languages: ['perl'] } ); hljs.initHighlightingOnLoad();</script>|);

    my $pod_path = File::Spec->catfile("specs", $pod);
    my $pod_text = read_file($pod_path);

    # remove utf8 unbreak space
    $pod_text =~ s/\xc2\xa0/ /g; 

    my $output_path = File::Spec->catfile("source", $pod);
    $output_path =~ s/\.pod|\.pl/\.html/i;
    print "$pod_path -> $output_path\n";

    my $css_path = File::Spec->abs2rel( abs_path("default.css"), dirname($output_path) );
    $css_path =~ s/\\/\//g;

    $p->html_css(qq|<link rel="stylesheet" href="http://yandex.st/highlightjs/8.0/styles/github.min.css">
<link rel="stylesheet" href="$css_path">|);

    my $html;

    $p->output_string(\$html);
    $p->parse_string_document($pod_text);

    write_file($output_path, {binmode => ':utf8'}, $html);
}

package My::Pod;

use base "Pod::Simple::HTML";
use URI::Escape::XS qw/uri_escape uri_unescape/;

sub general_url_escape {
    my ($self, $string) = @_;
    return uri_escape($string);
}
