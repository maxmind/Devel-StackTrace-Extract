package Devel::StackTrace::Extract;
use base qw(Exporter);

use strict;
use warnings;

our $VERSION = '1.000000';

use Devel::StackTrace;
use Devel::StackTrace::Frame;
use Scalar::Util qw(blessed);

our @EXPORT_OK;

sub extract_stack_trace {
    my $ex = shift;

    # non objects do not contain stack frames
    return undef unless blessed($ex);

    # anything that does StackTrace::Auto (including anything that does
    # Throwable::Error) will implement this
    return $ex->stack_trace if $ex->can('stack_trace');

    if ( $ex->isa('Mojo::Exception') ) {

        # make sure this is a modern version of Mojo using
        return undef unless $ex->can('frames');

        # it's possible for Mojo exceptions not to have stack frames
        my $frames = $ex->frames;
        return undef unless @{ $frames || [] };

        return _build_devel_trace_from_mojo_exception($ex);
    }

    # Exception::Class and Moose::Exception and friends use 'trace'.  Note the
    # importance of putting this *after* the Mojo::Exception check, as that
    # module implements a 'trace' method that *sets* the current stack trace,
    # not returns the current stack trace
    return $ex->trace if $ex->can('trace');

    # dunno how to get the stack trace, give up and return undef
    return undef;
}
push @EXPORT_OK, 'extract_stack_trace';

sub _build_devel_trace_from_mojo_exception {
    my $ex = shift;

    my $message = $ex->message;
    my $frames  = $ex->frames;

    my $trace = Devel::StackTrace->new(
        message     => $message,
        skip_frames => ~0 - 1,    # skip all frames, we're doing this by hand!
    );

    # convert the Mojo::Exception frames into Devel::StackTrace::Frame frames
    my @new_frames;
    foreach my $old_frame ( @{$frames} ) {

        # right now this is a somewhat undocumented interface to
        # Devel::StackFrame::Frame, but Dave Rolsky is at least aware
        # that this code does this.
        push @new_frames, Devel::StackTrace::Frame->new(
            $old_frame,
            [],    # we don't know the parameters that were passed, ooops

            # these are all the default from Devel::StackTrace
            undef,       # respect_overload,
            undef,       # max_arg_length
            $message,    # message
            undef,       # indent
        );
    }

    # work around of bug in Devel::StackTrace 2.00 where it still tries to
    # convert the raw frames into frames if you manually set them unless you've
    # read the frames once
    $trace->frames;

    $trace->frames(@new_frames);
    return $trace;
}

1;

__END__

=head1 NAME

Devel::StackTrace::Extract - extract a stack trace from an exception object

=head1 DESCRIPTION

It's popular to store stack traces in objects that are thrown as exceptions,
but, this being Perl, there's more than one way to do it.  This module
provides a simple interface to attempt to extract the stack trace from various
well known exception classes that are on the CPAN.

=head1 FUNCTION

Exported on demand or can be used fully qualified

=head2 extract_stack_trace($exception_object)

Returns a Devel::StackTrace stack trace object extracted from the exception
object or returns undef if no stack trace can be extracted with the current
heuristics.

The current rules that this uses to determine how to get a stack trace are, in
order, as follows (these are subject to change without notice):

=over

=item If it has a method called C<stack_trace> use that

This works with anything that uses the StackTrace::Auto Moose/Moo role, or
subclasses the Throwable::Exception class.

=item If it is a Mojo::Exception, and has a method called C<frames> use that

If we have a modern Mojo::Exception object with a C<frames> method, and it has
its frames populated (i.e. someone used the C<trace> method, or called C<throw>)
then we'll synthesize a Devel::StackTrace instance from that.

=item If it has a C<trace> method call that

This works for Exception::Class built exception objects, as well as any
Moose::Exception instances.

=back

=head1 BUGS

The heuristics in this make no attempt to check whatever is returned by the
exception classes are valid Devel::StackTrace objects

Mojo::Exception objects don't keep track of the arguments that are passed to a
stack frame, so the Devel::StackTrace that this synthesizes acts as if every
subroutine was called without arguments.

=head1 SEE ALSO

L<Devel::StackTrace>

L<Throwable::Error> and L<StackTrace::Auto>

L<Exception::Class>

L<Moose::Exception>

L<Mojo::Exception>
