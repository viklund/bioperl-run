# $Id$
#
# BioPerl module for Bio::Tools::Run::Phylo::PAML::Yn00
#
# Cared for by Jason Stajich <jason@bioperl.org>
#
# Copyright Jason Stajich
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Tools::Run::Phylo::PAML::Baseml - Wrapper aroud the PAML program baseml

=head1 SYNOPSIS

  use Bio::Tools::Run::Phylo::PAML::Baseml;
  use Bio::AlignIO;
  my $alignio = new Bio::AlignIO(-format => 'phylip',
  	 		         -file   => 't/data/gf-s85.phylip');
  my $aln = $alignio->next_aln;

  my $bml = new Bio::Tools::Run::Phylo::PAML::Baseml();
  $bml->alignment($aln);
  my ($rc,$parser) = $bml->run();
  while( my $result = $parser->next_result ) {
    my @otus = $result->get_seqs();
    my $MLmatrix = $result->get_MLmatrix();
    # 0 and 1 correspond to the 1st and 2nd entry in the @otus array
    
  }

=head1 DESCRIPTION

This is a wrapper around the baseml program of PAML (Phylogenetic
Analysis by Maximum Likelihood) package of Ziheng Yang.  See
http://abacus.gene.ucl.ac.uk/software/paml.html for more information.

This module will generate a proper baseml.ctl file and will run the
program in a separate temporary directory to avoid creating temp files
all over the place and will cleanup after itself..

The values you can feed to the configuration file are documented here.

    'noisy'   => [ 0..3,9],
    'verbose' => [ 0,1,2], # 0:concise, 1:detailed, 2:too much
    'runmode' => [-2,0..5], 
    # for runmode
    # -2 pairwise
    # 0: use the provided tree structure(s) in treefile
    # 1,2: mean heuristic search by star-decomposition alg
    # 2: starts from star tree while 1 reads a multifurcating 
    # tree from treefile and ties to estimate the best 
    # bifurcating tree
    # 3: stepwise addition
    # 4: NNI perturbation with the starting tree
    # Tree search DOES NOT WORK WELL so estimate a tree
    # using other programs first
    'model'   => '0', 
    # for model
    # 0: JC69 (uncorrected)
    # 1: K80  (transitions/transversion weighted differently)
    # 2: F81
    # 3: F84
    # 4: HKY85
    # 5: T92 (Tamura 92) 
    # 6: TN93 (Tajima-Nei) correct for multiple substitutions
    # 7: REV (aka GTR)
    # 8: UNREST 
    # 9: REVu
    #10: UNRESTu
    # See Yang 1994 JME 39:105-111
    
    # model 8 special case of the REV model
    # model 9 is special case of unrestricted model
    # can also supply special rate parameters
    # so for example (from pamlDOC.pdf
    # $model  = '8 [2 (CT) (AG)]'; # TN93 
    # $model  = '8 [2 (TA AT TG CA CG) (AG)]'; # TN93
    # $model  = '9 [1 (TC CT AG GA)]; # K80
    # $model  = '9 [0]'; # JC69
    # $model  = '9 [11 (TA) (TG) (CT) (CA) (CG) (AT) (AC) (AG) (GT) (GC) (GA)],
    
    'outfile' => 'mlb',
    'fix_kappa'=> [0,1], # 0:estimate kappa, 1:fix kappa
    'kappa'    => '2.5', # initial or fixed kappa
    'fix_alpha'=> [1,0], # 0: estimate gamma shape param
    # 1: fix it at alpha
    'alpha'    => '0', # initial of fixed alpha
    # 0: infinity (constant rate)
    'Malpha'   => [0,1], # different alphas for genes
    
    'fix_rho'=> [1,0], # 0: estimate gamma shape param
		                          # 1: fix it at alpha
    'rho'    => '0', # initial of fixed alpha
    # 0: infinity (constant rate)
    
    'ncatG'    => '5', # number of categories in the dD,AdG, or nparkK models of rates
    'nparK'    => [0..4], # rate-class models 
    # 1:rk 2:rk&fK 
    # 3:rK&MK(1/K) 4:rK&MK
    'nhomo'    => [0..4], # 0 & 1: homogeneous, 
    # 2: kappa for brances
    # 3:N1 4:N2
    'getSE'    => [0,1],
    'RateAncestor' => [1,0,2], # rates (alpha > 0) or 
    # ancestral states
    'cleandata' => [1,0], # remove sites with 
    # ambiguity data (1:yes or 0:no)
    
    'fix_blength' => [-1,0,1,2], # 0: ignore, -1: random, 
    # 1: initial, 2: fixed
    
# 'icode'    => [ 0..10], # (with RateAncestor=1. 
    #try "GC" in data,model=4,Mgene=4)
    'ndata'    => [5,1..10],
    'clock'    => [0..3], # 0: no clock, 1: clock, 2: local clock, 3: CombinedAnalysis
    'Small_Diff' => '1e-6', #underflow issues?
    
=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org              - General discussion
  http://bioperl.org/MailList.shtml  - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via
email or the web:

  http://bioperl.org/bioperl-bugs/

=head1 AUTHOR - Jason Stajich

Email jason-at-bioperl.org

=head1 CONTRIBUTORS

Additional contributors names and emails here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::Tools::Run::Phylo::PAML::Baseml;
use vars qw(@ISA %VALIDVALUES $MINNAMELEN $PROGRAMNAME $PROGRAM);
use strict;
use Cwd;
use Bio::Root::Root;
use Bio::AlignIO;
use Bio::TreeIO;
use Bio::Tools::Run::WrapperBase;
use Bio::Tools::Phylo::PAML;

@ISA = qw(Bio::Root::Root Bio::Tools::Run::WrapperBase);


=head2 Default Values


=cut

BEGIN { 

    $MINNAMELEN = 25;
    $PROGRAMNAME = 'baseml'  . ($^O =~ /mswin/i ?'.exe':'');
    if( defined $ENV{'PAMLDIR'} ) {
	$PROGRAM = Bio::Root::IO->catfile($ENV{'PAMLDIR'},$PROGRAMNAME);
    }
    # valid values for parameters, the default one is always
    # the first one in the array
    # much of the documentation here is lifted directly from the codeml.ctl
    # example file provided with the package
    %VALIDVALUES = ( 
		     'noisy'   => [ 0..3,9],
		     'verbose' => [ 0,1,2], # 0:concise, 1:detailed, 2:too much
		     'runmode' => [-2,0..5], 
		     # for runmode
                     # -2 pairwise
		     # 0: use the provided tree structure(s) in treefile
		     # 1,2: mean heuristic search by star-decomposition alg
		     # 2: starts from star tree while 1 reads a multifurcating 
		     # tree from treefile and ties to estimate the best 
		     # bifurcating tree
		     # 3: stepwise addition
		     # 4: NNI perturbation with the starting tree
		     # Tree search DOES NOT WORK WELL so estimate a tree
		     # using other programs first
		     'model'   => '0', 
		     # for model
		     # 0: JC69 (uncorrected)
		     # 1: K80  (transitions/transversion weighted differently)
		     # 2: F81
		     # 3: F84
		     # 4: HKY85
		     # 5: T92 (Tamura 92) 
		     # 6: TN93 (Tajima-Nei) correct for multiple substitutions
		     # 7: REV (aka GTR)
		     # 8: UNREST 
		     # See Yang 1994 JME 39:105-111
		     
		     # model 8 special case of the REV model
		     # model 9 is special case of unrestricted model
		     # can also supply special rate parameters
		     # so for example (from pamlDOC.pdf
		     # $model  = '8 [2 (CT) (AG)]'; # TN93 
		     # $model  = '8 [2 (TA AT TG CA CG) (AG)]'; # TN93
		     # $model  = '9 [1 (TC CT AG GA)]; # K80
		     # $model  = '9 [0]'; # JC69
		     # $model  = '9 [11 (TA) (TG) (CT) (CA) (CG) (AT) (AC) (AG) (GT) (GC) (GA)],
		     
		     'outfile' => 'mlb',
		     'fix_kappa'=> [0,1], # 0:estimate kappa, 1:fix kappa
		     'kappa'    => '2.5', # initial or fixed kappa
		     'fix_alpha'=> [1,0], # 0: estimate gamma shape param
		                          # 1: fix it at alpha
		     'alpha'    => '0', # initial of fixed alpha
		                          # 0: infinity (constant rate)
		     'Malpha'   => [0,1], # different alphas for genes
		     
		     'fix_rho'=> [1,0], # 0: estimate gamma shape param
		                          # 1: fix it at alpha
		     'rho'    => '0', # initial of fixed alpha
		                          # 0: infinity (constant rate)
		     
		     'ncatG'    => '5', # number of categories in the dD,AdG, or nparkK models of rates
		     'nparK'    => [0..4], # rate-class models 
		                           # 1:rk 2:rk&fK 
                                           # 3:rK&MK(1/K) 4:rK&MK
		     'nhomo'    => [0..4], # 0 & 1: homogeneous, 
		                           # 2: kappa for brances
		                           # 3:N1 4:N2
		     'getSE'    => [0,1],
		     'RateAncestor' => [1,0,2], # rates (alpha > 0) or 
		                                # ancestral states
		     'cleandata' => [1,0], # remove sites with 
		                           # ambiguity data (1:yes or 0:no)
		     
		     'fix_blength' => [-1,0,1,2], # 0: ignore, -1: random, 
		                                  # 1: initial, 2: fixed
		     
#		     'icode'    => [ 0..10], # (with RateAncestor=1. 
		                             #try "GC" in data,model=4,Mgene=4)
		     'ndata'    => [5,1..10],
		     'clock'    => [0..3], # 0: no clock, 1: clock, 2: local clock, 3: CombinedAnalysis
		     'Small_Diff' => '1e-6', #underflow issues?
		     
		     );
}


=head2 program_name

 Title   : program_name
 Usage   : $obj->program_name()
 Function: holds the program name
 Returns:  string
 Args    : None

=cut

sub program_name {
    return $PROGRAMNAME;
}

=head2 program_dir

 Title   : program_dir
 Usage   : ->program_dir()
 Function: returns the program directory, obtiained from ENV variable.
 Returns:  string
 Args    :

=cut

sub program_dir {
            return Bio::Root::IO->catfile($ENV{PAMLDIR}) if $ENV{PAMLDIR};
}

=head2 new

 Title   : new
 Usage   : my $obj = new Bio::Tools::Run::Phylo::PAML::Yn00();
 Function: Builds a new Bio::Tools::Run::Phylo::PAML::Yn00 object 
 Returns : Bio::Tools::Run::Phylo::PAML::Yn00
 Args    : -alignment => the L<Bio::Align::AlignI> object
           -save_tempfiles => boolean to save the generated tempfiles and
                              NOT cleanup after onesself (default FALSE)

=cut

sub new {
  my($class,@args) = @_;

  my $self = $class->SUPER::new(@args);
  my ($aln,$st) = $self->_rearrange([qw(ALIGNMENT SAVE_TEMPFILES)],
				    @args);
  defined $aln && $self->alignment($aln);
  defined $st  && $self->save_tempfiles($st);
  
  $self->set_default_parameters();
  return $self;
}

=head2 run

 Title   : run
 Usage   : $yn->run();
 Function: run the yn00 analysis using the default or updated parameters
           the alignment parameter must have been set
 Returns : 3 values, 
           $rc = 1 for success, 0 for errors
           hash reference of the Yang calculated Ka/Ks values
                    this is a set of pairwise observations keyed as
                    sequencenameA->sequencenameB->datatype
           hash reference same as the previous one except it for the 
           Nei and Gojobori calculated Ka,Ks,omega values
 Args    : none


=cut

sub run{
   my ($self,$aln) = @_;
   ($aln) ||= $self->alignment();
   if( ! $aln ) { 
       $self->warn("must have supplied a valid aligment file in order to run yn00");
       return 0;
   }
   my ($tmpdir) = $self->tempdir();
   my ($tempseqFH,$tempseqfile);
   if( ! ref($aln) && -e $aln ) { 
       $tempseqfile = $aln;
   } else { 
       ($tempseqFH,$tempseqfile) = $self->io->tempfile
	   ('-dir' => $tmpdir, 
	    UNLINK => ($self->save_tempfiles ? 0 : 1));
       my $alnout = new Bio::AlignIO('-format'      => 'phylip',
				     '-fh'          => $tempseqFH,
				     '-interleaved' => 0,
				     '-idlength'    => $MINNAMELEN > $aln->maxdisplayname_length() ? $MINNAMELEN : $aln->maxdisplayname_length() +1);
       
       $alnout->write_aln($aln);
       $alnout->close();
       undef $alnout;   
       close($tempseqFH);
       undef $tempseqFH;
   } 
   # now let's print the baseml.ctl file.
   # many of the these programs are finicky about what the filename is 
   # and won't even run without the properly named file.  Ack
   
   my $baseml_ctl = "$tmpdir/baseml.ctl";
   open(YN, ">$baseml_ctl") or $self->throw("cannot open $baseml_ctl for writing");
   print YN "seqfile = $tempseqfile\n";

   my $outfile = $self->outfile_name;

   print YN "outfile = $outfile\n";
   my %params = $self->get_parameters;
   while( my ($param,$val) = each %params ) {
       print YN "$param = $val\n";
   }
   close(YN);
   my ($rc,$parser) = (1);
   {
       my $cwd = cwd();
       my $exit_status;
       chdir($tmpdir);
       my $ynexe = $self->executable();
       $self->throw("unable to find executable for 'yn'") unless $ynexe;
       open(RUN, "$ynexe |");
       my @output = <RUN>;
       $exit_status = close(RUN);
       $self->error_string(join('',@output));
       if( (grep { /\berr(or)?: /io } @output) || !$exit_status ) {
	   $self->warn("There was an error - see error_string for the program output");
	   $rc = 0;
       }
       eval {
	   $parser = new Bio::Tools::Phylo::PAML(-file => "$tmpdir/mlb", 
						 -dir => "$tmpdir");

       };
       if( $@ ) {
	   $self->warn($self->error_string);
       }
       chdir($cwd);
   }
   if( $self->verbose > 0 ) {
       open(IN, "$tmpdir/mlb");
       while(<IN>) {
	   $self->debug($_);
       }
   }
       
   unless ( $self->save_tempfiles ) {
      unlink("$baseml_ctl");
      $self->cleanup();
   }
   return ($rc,$parser);
}

=head2 error_string

 Title   : error_string
 Usage   : $obj->error_string($newval)
 Function: Where the output from the last analysus run is stored.
 Returns : value of error_string
 Args    : newvalue (optional)


=cut

sub error_string{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'error_string'} = $value;
    }
    return $self->{'error_string'};

}

=head2 alignment

 Title   : alignment
 Usage   : $codeml->align($aln);
 Function: Get/Set the L<Bio::Align::AlignI> object
 Returns : L<Bio::Align::AlignI> object
 Args    : [optional] L<Bio::Align::AlignI>
 Comment : We could potentially add support for running directly on a file
           but we shall keep it simple
 See also: L<Bio::SimpleAlign>

=cut

sub alignment{
   my ($self,$aln) = @_;
   if( defined $aln ) { 
       if( !ref($aln) || ! $aln->isa('Bio::Align::AlignI') ) { 
	   $self->warn("Must specify a valid Bio::Align::AlignI object to the alignment function");
	   return undef;
       }
       $self->{'_alignment'} = $aln;
   }
   return  $self->{'_alignment'};
}

=head2 get_parameters

 Title   : get_parameters
 Usage   : my %params = $self->get_parameters();
 Function: returns the list of parameters as a hash
 Returns : associative array keyed on parameter names
 Args    : none


=cut

sub get_parameters{
   my ($self) = @_;
   # we're returning a copy of this
   return %{ $self->{'_codemlparams'} };
}


=head2 set_parameter

 Title   : set_parameter
 Usage   : $codeml->set_parameter($param,$val);
 Function: Sets a codeml parameter, will be validated against
           the valid values as set in the %VALIDVALUES class variable.  
           The checks can be ignored if on turns of param checks like this:
             $codeml->no_param_checks(1)
 Returns : boolean if set was success, if verbose is set to -1
           then no warning will be reported
 Args    : $paramname => name of the parameter
           $value     => value to set the parameter to
 See also: L<no_param_checks()>

=cut

sub set_parameter{
   my ($self,$param,$value) = @_;
   if( ! defined $VALIDVALUES{$param} ) { 
       $self->warn("unknown parameter $param will not set unless you force by setting no_param_checks to true");
       return 0;
   } 
   if( ref( $VALIDVALUES{$param}) =~ /ARRAY/i &&
       scalar @{$VALIDVALUES{$param}} > 0 ) {
       
       unless ( grep {$value} @{ $VALIDVALUES{$param} } ) {
	   $self->warn("parameter $param specified value $value is not recognized, please see the documentation and the code for this module or set the no_param_checks to a true value");
	   return 0;
       }
   }
   $self->{'_codemlparams'}->{$param} = $value;
   return 1;
}

=head2 set_default_parameters

 Title   : set_default_parameters
 Usage   : $codeml->set_default_parameters(0);
 Function: (Re)set the default parameters from the defaults
           (the first value in each array in the 
	    %VALIDVALUES class variable)
 Returns : none
 Args    : boolean: keep existing parameter values


=cut

sub set_default_parameters{
   my ($self,$keepold) = @_;
   $keepold = 0 unless defined $keepold;
   
   while( my ($param,$val) = each %VALIDVALUES ) {
       # skip if we want to keep old values and it is already set
       next if( defined $self->{'_codemlparams'}->{$param} && $keepold);
       if(ref($val)=~/ARRAY/i ) {
	   $self->{'_codemlparams'}->{$param} = $val->[0];
       }  else { 
	   $self->{'_codemlparams'}->{$param} = $val;
       }
   }
}


=head1 Bio::Tools::Run::Wrapper methods

=cut

=head2 no_param_checks

 Title   : no_param_checks
 Usage   : $obj->no_param_checks($newval)
 Function: Boolean flag as to whether or not we should
           trust the sanity checks for parameter values  
 Returns : value of no_param_checks
 Args    : newvalue (optional)


=cut

=head2 save_tempfiles

 Title   : save_tempfiles
 Usage   : $obj->save_tempfiles($newval)
 Function: 
 Returns : value of save_tempfiles
 Args    : newvalue (optional)


=cut

=head2 outfile_name

 Title   : outfile_name
 Usage   : my $outfile = $codeml->outfile_name();
 Function: Get/Set the name of the output file for this run
           (if you wanted to do something special)
 Returns : string
 Args    : [optional] string to set value to


=cut


=head2 tempdir

 Title   : tempdir
 Usage   : my $tmpdir = $self->tempdir();
 Function: Retrieve a temporary directory name (which is created)
 Returns : string which is the name of the temporary directory
 Args    : none


=cut

=head2 cleanup

 Title   : cleanup
 Usage   : $codeml->cleanup();
 Function: Will cleanup the tempdir directory after a PAML run
 Returns : none
 Args    : none


=cut

=head2 io

 Title   : io
 Usage   : $obj->io($newval)
 Function:  Gets a L<Bio::Root::IO> object
 Returns : L<Bio::Root::IO>
 Args    : none


=cut

1;