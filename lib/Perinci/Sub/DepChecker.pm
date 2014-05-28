package Perinci::Sub::DepChecker;

use 5.010001;
use strict;
use warnings;
use experimental 'smartmatch';
#use Log::Any '$log';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       check_deps
                       dep_satisfy_rel
                       list_mentioned_dep_clauses
               );

# VERSION
# DATE

my $pa;

sub check_deps {
    my ($val) = @_;
    #say "D:check: ", dump($val);
    for my $dname (keys %$val) {
        my $dval = $val->{$dname};
        unless (defined &{"checkdep_$dname"}) {
            # give a chance to load from a module first
            eval { require "Perinci/Sub/Dep/$dname.pm" };
            return "Unknown dependency type: $dname"
                unless defined &{"checkdep_$dname"};
        }
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

sub checkdep_prog {
    my ($cval) = @_;

    if ($cval =~ m!/!) {
        return "Program $cval not executable" unless (-x $cval);
    } else {
        require File::Which;
        return "Program $cval not found in PATH (".
            join(":", File::Spec->path).")"
                unless File::Which::which($cval);
    }
    "";
}

sub _pa {
    return $pa if $pa;
    require Perinci::Access;
    $pa = Perinci::Access->new;
    $pa;
}

sub checkdep_pkg {
    my ($cval) = @_;
    my $res = _pa->request(info => $cval);
    $res->[0] == 200 or return "Can't perform 'info' Riap request on '$cval': ".
        "$res->[0] $res->[1]";
    $res->[2]{type} eq 'package' or return "$cval is not a Riap package";
    "";
}

sub checkdep_func {
    my ($cval) = @_;
    my $res = _pa->request(info => $cval);
    $res->[0] == 200 or return "Can't perform 'info' Riap request on '$cval': ".
        "$res->[0] $res->[1]";
    $res->[2]{type} eq 'function' or return "$cval is not a Riap function";
    "";
}

# for backward-compatibility
sub checkdep_exec { checkdep_prog(@_) }

# we check this dep by checking arguments, so we'll let something like
# Perinci::Sub::Wrapper to do it
sub checkdep_tmp_dir { "" }

# we check this dep by checking arguments, so we'll let something like
# Perinci::Sub::Wrapper to do it
sub checkdep_trash_dir { "" }

# we check this dep by checking arguments, so we'll let something like
# Perinci::Sub::Wrapper to do it
sub checkdep_undo_trash_dir { "" }

sub _all_elems_is {
    my ($ary, $el) = @_;
    (grep {$_ eq $el} @$ary) && !(grep {$_ ne $el} @$ary);
}

sub _all_nonblank_elems_is {
    my ($ary, $el) = @_;
    (grep {$_ eq $el} @$ary) && !(grep {$_ && $_ ne $el} @$ary);
}

sub dep_satisfy_rel {
    my ($wanted, $deps) = @_;
    #$log->tracef("=> dep_satisfy_rel(%s, %s)", $wanted, $deps);

    my $res;
    for my $dname (keys %$deps) {
        my $dval = $deps->{$dname};

        if ($dname eq 'all') {
            my @r = map { dep_satisfy_rel($wanted, $_) } @$dval;
            #$log->tracef("all: %s", \@r);
            next unless @r;
            return "impossible" if "impossible" ~~ @r;
            return "impossible" if "must" ~~ @r && "must not" ~~ @r;
            return "must"       if "must" ~~ @r;
            return "must not"   if "must not" ~~ @r;
            return "might"      if _all_nonblank_elems_is(\@r, "might");
        } elsif ($dname eq 'any') {
            my @r = map { dep_satisfy_rel($wanted, $_) } @$dval;
            #$log->tracef("any: %s", \@r);
            next unless @r;
            return "impossible" if "impossible" ~~ @r;
            return "must"       if _all_elems_is(\@r, "must");
            return "must not"   if _all_elems_is(\@r, "must not");
            next                if _all_elems_is(\@r, "");
            return "might";
        } elsif ($dname eq 'none') {
            my @r = map { dep_satisfy_rel($wanted, $_) } @$dval;
            #$log->tracef("none: %s", \@r);
            next unless @r;
            return "impossible" if "impossible" ~~ @r;
            return "impossible" if "must" ~~ @r && "must not" ~~ @r;
            return "must not"   if "must" ~~ @r;
            return "must"       if "must not" ~~ @r;
            return "might"      if _all_nonblank_elems_is(\@r, "might");
        } else {
            return "must" if $dname eq $wanted;
        }
    }
    "";
}

sub list_mentioned_dep_clauses {
    my ($deps, $res) = @_;
    $res //= [];
    for my $dname (keys %$deps) {
        my $dval = $deps->{$dname};
        push @$res, $dname unless $dname ~~ @$res;
        if ($dname =~ /\A(?:all|any|none)\z/) {
            list_mentioned_dep_clauses($_, $res) for @$dval;
        }
    }
    $res;
}

1;
# ABSTRACT: Check dependencies from 'deps' property

=for Pod::Coverage ^(checkdep_.*)$

=head1 SYNOPSIS

 use Perinci::Spec::DepChecker qw(check_deps dep_must_be_satisfied);

 my $err = check_deps($meta->{deps});
 print "Dependencies not met: $err" if $err;

 print "We need to prepare foo"
     if dep_satisfy_rel('foo', $meta->{deps}) =~ /^(?:must|might)$/;


=head1 DESCRIPTION

The 'deps' spec clause adds information about subroutine dependencies. This
module performs check on it.

This module is currently mainly used by L<Perinci::Sub::Wrapper>.


=head1 FUNCTIONS

None is exported by default, but every function is exportable.

=head2 check_deps($deps) => ERRSTR

Check dependencies. Will in turn call various C<checkdep_NAME()> subroutines.
Return empty string if all dependencies are met, or a string containing an error
message stating a dependency error.

Example:

 my $err = check_deps({env=>'DEBUG'});

Will check environment variable C<DEBUG>. If true, will return an empty string.
Otherwise will set $err with something like C<Environment variable DEBUG not
set/true>.

Another example:

 my $err = check_deps({ all=>[{env=>"A"}, {env=>"B", prog=>"bc"}] });

The above will check environment variables C<A>, C<B>, as well as program C<bc>.
All dependencies must be met (because we use the C<and> metaclause).

To support a custom dependency named C<NAME>, just define C<checkdep_NAME>
subroutine in L<Perinci::Sub::DepChecker> package which accepts a value and
should return an empty string on success or an error message string.

=head2 dep_satisfy_rel($name, $deps) => STR

Check dep satisfication relationship, i.e. whether dependency named C<$name>
must be satisfied in C<$deps>. Due to B<all>, B<any>, and B<none> clauses, this
needs to be checked recursively and might yield an inconclusive answer
("maybe").

Return "must" if C<$name> definitely must be satisfied in C<$deps>, "must not"
if definitely not, "" if need not be satisfied (dep clause does not exist in
deps), "impossible" if condition is impossible to be satisfied (due to
conflicts), "might" if dep might need to be satisfied (but might also not).

Examples:

 dep_satisfy_rel('env', {env=>"A"})              # => "must"
 dep_satisfy_rel('a', {all=>[{a=>1}, {b=>1}]})   # => "must"
 dep_satisfy_rel('a', {b=>2})                    # => ""
 dep_satisfy_rel('a', {none=>[{a=>1}, {b=>1}]})  # => "must not"
 dep_satisfy_rel('c', {none=>[{a=>1}, {b=>1}]})  # => ""
 dep_satisfy_rel('a', {any=>[{a=>1}, {b=>1}]})   # => "might"
 dep_satisfy_rel('a', {all=>[{a=>1},
                             {none=>[{a=>1}]}]}) # => "impossible"

This function is useful if we want to prepare something that "must" or "might"
be needed, or want to avoid preparing something that "must not" be present.

=head2 list_mentioned_dep_clauses($deps) => ARRAYREF

List all dep clauses mentioned in $deps. The returned array is I<not> sorted
alphabetically, so you will have to do it yourself if you need it sorted.

Example:

 list_mentioned_dep_clauses({any=>[{a=>1}, {b=>1}]}) # => [qw/any a b/]


=head1 SEE ALSO

L<Perinci>

'deps' section in L<Rinci::function>

=cut
