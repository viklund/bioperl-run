# BioPerl module for Bio::Tools::Run::Phylo::Phylip::ProtDist
#
# Created by
#
# Shawn Hoon 
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME 

Bio::Tools::Run::Phylo::Phylip::ProtDist - Wrapper for the phylip program protdist by Joseph Felsentein for creating a distance matrix comparing protein sequences from a multiple alignment file or a L<Bio::SimpleAlign> object and returns a hash ref to the table

=head1 SYNOPSIS

#Create a SimpleAlign object
@params = ('ktuple' => 2, 'matrix' => 'BLOSUM');
$factory = Bio::Tools::Run::Alignment::Clustalw->new(@params);
$inputfilename = 't/data/cysprot.fa';
$aln = $factory->align($inputfilename); # $aln is a SimpleAlign object.
	
#Create the Distance Matrix 
#using a default PAM matrix  and id name lengths limit of 30
#note to use id name length greater than the standard 10 in protdist, you will need
#to modify the protdist source code

$protdist_factory = Bio::Tools::Run::Phylo::Phylip::ProtDist->new(@params);
my $matrix  = $protdist_factory->create_distance_matrix($aln);
	
#finding the distance between two sequences
my $distance = $matrix->{'protein_name_1'}{'protein_name_2'};

#Alternatively, one can create the matrix by passing in a file name containing a multiple alignment in phylip format
$protdist_factory = Bio::Tools::Run::Phylo::Phylip::ProtDist->new(@params);
my $matrix  = $protdist_factory->create_distance_matrix('/home/shawnh/prot.phy');


=head1 PARAMTERS FOR PROTDIST COMPUTATION

=head2 
Title 		:MODEL
Description	:(optional) 	This sets the model of amino acid substitution used in the calculation of the distances.
 				3 different models are supported: 
				PAM	Dayhoff PAM Matrix(default) 
				KIMURA	Kimura's Distance
				CAT	Categories Distance
				Usage: 
				@params = ('model'=>'X');#where X is one of the values above
				Defaults to PAM
				For more information on the usage of the different models, please refer to the documentation
			        defaults to Equal (0.25,0.25,0.25,0.25)
				found in the phylip package.
							
*ALL SUBSEQUENT PARAMETERS WILL ONLY WORK IN CONJUNCTION WITH THE Categories Distance MODEL*

=head2 GENCODE 
	Title		: GENCODE 
	Description	: (optional)	This option allows the  user to select among various nuclear and mitochondrial genetic codes.
			Acceptable Values:
			U           Universal
   			M           Mitochondrial
			V           Vertebrate mitochondrial
			F           Fly mitochondrial
			Y           Yeast mitochondrial
			Usage:
			@params = ('gencode'=>'X'); where X is one of the letters above	
			Defaults to U 

=head2 CATEGORY 
Title		: CATEGORY 
Description : (optional)This option sets the categorization of amino acids
			all have groups: (Glu Gln Asp Asn), (Lys Arg His), (Phe Tyr Trp)
			plus:
			G	George/Hunt/Barker: (Cys), (Met   Val  Leu  Ileu), (Gly  Ala  Ser  Thr    Pro)
			C	Chemical:           (Cys   Met), (Val  Leu  Ileu    Gly  Ala  Ser  Thr), (Pro)
			H	Hall:               (Cys), (Met   Val  Leu  Ileu), (Gly  Ala  Ser  Thr), (Pro)
			Usage:		
			@params = ('category'=>'X'); where X is one of the letters above
			Defaults to G

=head2 PROBCHANGE 
    Title       : PROBCHANGE 
    Description : (optional)    This option sets the ease of changing category of amino acid.
				(1.0 if no difficulty of changing,less if less easy. Can't be negative)
				Usage:
				@params = ('probchange'=>X) where 0<=X<=1							
				Defaults to 0.4570
=head2 TRANS 
    Title       : TRANS
    Description : (optional)    This option sets transition/transversion ratio
				can be any positive number
                                Usage:
                                @params = ('trans'=>X) where X >= 0 
                                Defaults to 2
=head2 FREQ 
    Title       : FREQ 
    Description : (optional)    This option sets the frequency of each base (A,C,G,T)
				The sum of the frequency must sum to 1.
				For example A,C,G,T = (0.25,0.5,0.125,0.125) 
                                Usage:
                                @params = ('freq'=>('W','X','Y','Z') where W + X + Y + Z = 1 
				Defaults to Equal (0.25,0.25,0.25,0.25)

	
=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org          - General discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
 the bugs and their resolution.  Bug reports can be submitted via
 email or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Shawn Hoon 

Email shawnh@fugu-sg.org 

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

#'

	
package Bio::Tools::Run::Phylo::Phylip::ProtDist;

use vars qw($AUTOLOAD @ISA $PROGRAM $PROGRAMDIR
	    $TMPDIR $TMPOUTFILE @PROTPARS_PARAMS @OTHER_SWITCHES
	    %OK_FIELD);
use strict;
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::TreeIO;
use Bio::Root::Root;
use Bio::Root::IO;

@ISA = qw(Bio::Root::Root Bio::Root::IO);

# You will need to enable the protdist program. This
# can be done in (at least) 3 ways:
#
# 1. define an environmental variable PHYLIPDIR:
# export PHYLIPDIR=/home/shawnh/PHYLIP/bin
#
# 2. include a definition of an environmental variable CLUSTALDIR in
# every script that will use Clustal.pm.
# $ENV{PHYLIPDIR} = '/home/shawnh/PHYLIP/bin';
#
# 3. You can set the path to the program through doing:
# my @params('program'=>'/usr/local/bin/protdist');
# my $protdist_factory = Bio::Tools::Run::Phylo::Phylip::ProtDist->new(@params);
# 


BEGIN {

    if (defined $ENV{PHYLIPDIR}) {
	$PROGRAMDIR = $ENV{PHYLIPDIR} || '';
	$PROGRAM = Bio::Root::IO->catfile($PROGRAMDIR,
					  'protdist'.($^O =~ /mswin/i ?'.exe':''));
    }
    else {
	$PROGRAM = 'protdist';
    }
	@PROTPARS_PARAMS = qw(MODEL GENCODE CATEGORY PROBCHANGE TRANS FREQ);
	@OTHER_SWITCHES = qw(QUIET);
	foreach my $attr(@PROTPARS_PARAMS,@OTHER_SWITCHES) {
		$OK_FIELD{$attr}++;
	}
}

sub new {
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);
    # to facilitiate tempfile cleanup
    $self->_initialize_io();

    my ($attr, $value);
    (undef,$TMPDIR) = $self->tempdir(CLEANUP=>1);
    (undef,$TMPOUTFILE) = $self->tempfile(-dir => $TMPDIR);
    while (@args)  {
	$attr =   shift @args;
	$value =  shift @args;
	next if( $attr =~ /^-/ ); # don't want named parameters
	if ($attr =~/PROGRAM/i) {
		$self->program($value);
		next;
	}
	if ($attr =~ /IDLENGTH/i){
		$self->idlength($value);
		next;
	}
	$self->$attr($value);	
    }
    if (! defined $self->program) {
	$self->program($PROGRAM);
    }
    unless ($self->exists_protdist()) {
	if( $self->verbose >= 0 ) {
		warn "protdist program not found as ".$self->program." or not executable. \n  The phylip package can be obtained from http://evolution.genetics.washington.edu/phylip.html \n";
	}
    }
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    $attr =~ s/.*:://;
    $attr = uc $attr;
    $self->throw("Unallowed parameter: $attr !") unless $OK_FIELD{$attr};
    $self->{$attr} = shift if @_;
    return $self->{$attr};
}


=head2  exists_protdist()

 Title   : exists_protdist
 Usage   : $protdistfound = Bio::Tools::Run::Alignment::Tree->exists_protdist()
 Function: Determine whether protdist program can be found on current host
 Example :
 Returns : 1 if protdist program found at expected location, 0 otherwise.
 Args    :  none

=cut


sub exists_protdist{
    my $self = shift;
    if( my $f = Bio::Root::IO->exists_exe($PROGRAM) ) {
	$PROGRAM = $f if( -e $f );
	return 1;
    }
}

=head2 program

 Title   : program
 Usage   : $obj->program($newval)
 Function: 
 Returns : value of program
 Args    : newvalue (optional)


=cut

sub program{
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'program'} = $value;
    }
    return $self->{'program'};

}

=head2 idlength 

 Title   : idlength 
 Usage   : $obj->idlength ($newval)
 Function: 
 Returns : value of idlength 
 Args    : newvalue (optional)


=cut

sub idlength{
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'idlength'} = $value;
    }
    return $self->{'idlength'};

}


=head2  create_distance_matrix 

 Title   : create_distance_matrix 
 Usage   :
	$inputfilename = 't/data/prot.phy';
	$matrix= $prodistfactory->create_distance_matrix($inputfilename);
or
	$seq_array_ref = \@seq_array; @seq_array is array of Seq objs
	$aln = $protdistfactory->align($seq_array_ref);
	$matrix = $protdistfactory->create_distance_matrix($aln);

 Function: Create a distance matrix from a SimpleAlign object or a multiple alignment file 
 Example :
 Returns : Hash ref to a hash of a hash 
 Args    : Name of a file containing a multiple alignment in Phylip format
           or an SimpleAlign object 

 Throws an exception if argument is not either a string (eg a
 filename) or a Bio::SimpleAlign object. If
 argument is string, throws exception if file corresponding to string
 name can not be found. 

=cut

sub create_distance_matrix{

    my ($self,$input) = @_;
    my ($infilename);

# Create input file pointer
  	$infilename = $self->_setinput($input);
    if (!$infilename) {$self->throw("Problems setting up for protdist. Probably bad input data in $input !");}

# Create parameter string to pass to protdist program
    my $param_string = $self->_setparams();

# run protdist
    my $aln = $self->_run($infilename,$param_string);
}

#################################################

=head2  _run

 Title   :  _run
 Usage   :  Internal function, not to be called directly	
 Function:   makes actual system call to protdist program
 Example :
 Returns : Bio::Tree object
 Args    : Name of a file containing a set of multiple alignments in Phylip format 
           and a parameter string to be passed to protdist


=cut

sub _run {
    my ($self,$infile,$param_string) = @_;
    my $instring;
    $instring =  $infile."\n$param_string";
    $self->debug( "Program ".$self->program."\n");

	#open a pipe to run protdist to bypass interactive menus
    if ($self->quiet() || $self->verbose() < 0) {
	open(PROTPARS,"|".$self->program.">/dev/null");
    }
    else {
	open(PROTPARS,"|".$self->program);
    }
    print PROTPARS $instring;
    close(PROTPARS);	

	#get the results
    my $path = `pwd`;
    chomp($path);
    my $outfile = $path."/outfile";

    $self->throw("protdist did not create matrix correctly") unless (-e $outfile);

	#Create the distance matrix here
    my @values;
    open(DIST, "outfile");
    while (<DIST>){
	next if (/^\s+\d+$/);
        my @line = split /\s+/,$_;
        push @values,[@line];
    }
	#list of sequences 
    my @name = map{$_->[0]}@values;
    my %dist;
	#create the matrix using a hash of hash 
    my $i = 0;
    foreach my $name (@name){
	my $j = 1;
        foreach my $n(@name){
		$dist{$name}{$n} = $values[$i][$j];
		$j++;
	}
    	$i++;
    }
		
    # Clean up the temporary files created along the way...
    unlink $outfile;
	
    return \%dist;
}


=head2  _setinput()

 Title   :  _setinput
 Usage   :  Internal function, not to be called directly	
 Function:   Create input file for protdist program
 Example :
 Returns : name of file containing a multiple alignment in Phylip format 
 Args    : SimpleAlign object reference or input file name


=cut

sub _setinput {
    my ($self, $input) = @_;
    my ($alnfilename,$tfh);

    # suffix is used to distinguish alignment files  from an align obkect
	#If $input is not a  reference it better be the name of a file with the sequence/

    #  a phy formatted alignment file 
  	unless (ref $input) {
        # check that file exists or throw
        $alnfilename= $input;
        unless (-e $input) {return 0;}
		return $alnfilename;
    }

    #  $input may be a SimpleAlign Object
    if ($input->isa("Bio::SimpleAlign")) {
        #  Open temporary file for both reading & writing of BioSeq array
		($tfh,$alnfilename) = $self->tempfile(-dir=>$TMPDIR);
		my $alnIO = Bio::AlignIO->new(-fh => $tfh, -format=>'phylip',idlength=>$self->idlength());
		$alnIO->write_aln($input);
		$alnIO->close();
		return $alnfilename;		
	}
	return 0;
}

=head2  _setparams()

 Title   :  _setparams
 Usage   :  Internal function, not to be called directly	
 Function:   Create parameter inputs for protdist program
 Example :
 Returns : parameter string to be passed to protdist
 Args    : name of calling object

=cut

sub _setparams {
    my ($attr, $value, $self);

	#do nothing for now
    $self = shift;
    my $param_string = "";
	my $cat = 0;
	foreach  my $attr ( @PROTPARS_PARAMS) {
        	$value = $self->$attr();
	        next unless (defined $value);
      		if ($attr =~/MODEL/i){
			if ($value=~/CAT/i){
				$cat = 1;
				$param_string .= "P\nP\n";
				next;
			}
			elsif($value=~/KIMURA/i){
				$param_string .= "P\nY\n";
				return $param_string;
			}
			else {
				$param_string.="Y\n";
				return $param_string;
			}
		}
		if ($cat == 1){
			if($attr =~ /GENCODE/i){
				$self->throw("Unallowed value for genetic code") unless ($value =~ /[U,M,V,F,Y]/);
				$param_string .= "C\n$value\n";
			}
			if ($attr =~/CATEGORY/i){
				$self->throw("Unallowed value for categorization of amino acids") unless ($value =~/[C,H,G]/);
				$param_string .= "A\n$value\n";
			}
			if ($attr =~/PROBCHANGE/i){
				if (($value =~ /\d+/)&&($value >= 0) && ($value < 1)){
					$param_string .= "E\n$value\n";
				}
				else {
					$self->throw("Unallowed value for probability change category");  
				}
			}
			if ($attr =~/TRANS/i){
				if (($value=~/\d+/) && ($value >=0)){
					$param_string .="T\n$value\n";
				}
			}
			if ($attr =~ /FREQ/i){
				my @freq = split(",",$value);	
				if ($freq[0] !~ /\d+/){ #a letter provided (sets frequencies equally to 0.25)
					$param_string .="F\n".$freq[0]."\n";
				}
				elsif ($#freq ==  3) {#must have 4 digits for each base
					$param_string .="F\n";
					foreach my $f (@freq){
						$param_string.="$f\n";
					}
				}
				else {
					$self->throw("Unallowed value fo base frequencies");
				}
			}
		}
	} 
    $param_string .="Y\n";

    return $param_string;
}

1; # Needed to keep compiler happy
