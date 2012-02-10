package Perinci::Sub::DepChecker;

use 5.010;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(check_deps);

# VERSION

sub check_deps {
    my ($val) = @_;
    #say "D:check: ", dump($val);
    while (my ($dname, $dval) = each %$val) {
        return "Unknown dependency type: $dname"
            unless defined &{"checkdep_$dname"};
        my $check = \&{"checkdep_$dname"};
        my $res = $check->($dval);
        if ($res) {
            $res = "$dname: $res";
            return $res;
        }
    }
    "";
}

sub checkdep_all {
    my ($val) = @_;
    #say "D:check_all: ", dump($val);
    for (@$val) {
        my $res = check_deps($_);
        return "Some dependencies not met: $res" if $res;
    }
    "";
}

sub checkdep_any {
    my ($val) = @_;
    my $nfail = 0;
    for (@$val) {
        return "" unless check_deps($_);
        $nfail++;
    }
    $nfail ? "None of the dependencies are met" : "";
}

sub checkdep_none {
    my ($val) = @_;
    for (@$val) {
        my $res = check_deps($_);
        return "A dependency is met when it shouldn't: $res" unless $res;
    }
    "";
}

sub checkdep_env {
    my ($cval) = @_;
    $ENV{$cval} ? "" : "Environment variable $cval not set/true";
}

sub checkdep_code {
    my ($cval) = @_;
    $cval->() ? "" : "code doesn't return true value";
}

sub checkdep_exec {
    my ($cval) = @_;

    if ($cval =~ m!/!) {
        return "Executable $cval not available" unless (-x $cval);
    } else {
        require File::Which;
        return "$cval not found in PATH" unless File::Which::which($cval);
    }
    "";
}

1;
# ABSTRACT: Check dependencies from 'deps' property

=head1 SYNOPSIS

 use Perinci::Spec::DepChecker qw(check_deps);
 my $err = check_deps($spec->{deps});
 print "Dependencies not met: $err" if $err;


=head1 DESCRIPTION

The 'deps' spec clause adds information about subroutine dependencies. This
module performs check on it.

This module is mainly used by L<Perinci::Sub::Wrapper>.


=head1 SEE ALSO

L<Perinci>

=cut
