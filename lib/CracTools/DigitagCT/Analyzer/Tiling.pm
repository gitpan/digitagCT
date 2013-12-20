###############################################################################
#                                                                             #
#    Copyright © 2012-2013 -- IRB/INSERM                                      #
#                            (Institut de Recherche en Biothérapie /          #
#                             Institut National de la Santé et de la          #
#                             Recherche Médicale)                             #
#                                                                             #
#  Auteurs/Authors:  Anthony BOUREUX <anthony.boureux@univ-montp2.fr>         #
#                    Jerôme AUDOUX <jerome.audoux@univ-montp2.fr>             #
#                    Nicolas PHILIPPE <nicolas.philippe@inserm.fr>            #
#                                                                             #
#  -------------------------------------------------------------------------  #
#                                                                             #
#  Ce fichier fait partie de la suite CracTools qui contient plusieurs pipeline# 
#  intégrés permettant de traiter les évênements biologiques présents dans du #
#  RNA-Seq. Les CracTools travaillent à partir d'un fichier SAM de CRAC et d'un# 
#  fichier d'annotation au format GFF3.                                       #
#                                                                             #
#  Ce logiciel est régi  par la licence CeCILL  soumise au droit français et  #
#  respectant les principes  de diffusion des logiciels libres.  Vous pouvez  #
#  utiliser, modifier et/ou redistribuer ce programme sous les conditions de  #
#  la licence CeCILL  telle que diffusée par le CEA,  le CNRS et l'INRIA sur  #
#  le site "http://www.cecill.info".                                          #
#                                                                             #
#  En contrepartie de l'accessibilité au code source et des droits de copie,  #
#  de modification et de redistribution accordés par cette licence, il n'est  #
#  offert aux utilisateurs qu'une garantie limitée.  Pour les mêmes raisons,  #
#  seule une responsabilité  restreinte pèse  sur l'auteur du programme,  le  #
#  titulaire des droits patrimoniaux et les concédants successifs.            #
#                                                                             #
#  À  cet égard  l'attention de  l'utilisateur est  attirée sur  les risques  #
#  associés  au chargement,  à  l'utilisation,  à  la modification  et/ou au  #
#  développement  et à la reproduction du  logiciel par  l'utilisateur étant  #
#  donné  sa spécificité  de logiciel libre,  qui peut le rendre  complexe à  #
#  manipuler et qui le réserve donc à des développeurs et des professionnels  #
#  avertis  possédant  des  connaissances  informatiques  approfondies.  Les  #
#  utilisateurs  sont donc  invités  à  charger  et  tester  l'adéquation du  #
#  logiciel  à leurs besoins  dans des conditions  permettant  d'assurer  la  #
#  sécurité de leurs systêmes et ou de leurs données et,  plus généralement,  #
#  à l'utiliser et l'exploiter dans les mêmes conditions de sécurité.         #
#                                                                             #
#  Le fait  que vous puissiez accéder  à cet en-tête signifie  que vous avez  #
#  pris connaissance  de la licence CeCILL,  et que vous en avez accepté les  #
#  termes.                                                                    #
#                                                                             #
#  -------------------------------------------------------------------------  #
#                                                                             #
#  This file is part of the CracTools which provide several integrated        #
#  pipeline to analyze biological events present in RNA-Seq data. CracTools   #
#  work on a SAM file generated by CRAC and an annotation file in GFF3 format.#
#                                                                             #
#  This software is governed by the CeCILL license under French law and       #
#  abiding by the rules of distribution of free software. You can use,        #
#  modify and/ or redistribute the software under the terms of the CeCILL     #
#  license as circulated by CEA, CNRS and INRIA at the following URL          #
#  "http://www.cecill.info".                                                  #
#                                                                             #
#  As a counterpart to the access to the source code and rights to copy,      #
#  modify and redistribute granted by the license, users are provided only    #
#  with a limited warranty and the software's author, the holder of the       #
#  economic rights, and the successive licensors have only limited            #
#  liability.                                                                 #
#                                                                             #
#  In this respect, the user's attention is drawn to the risks associated     #
#  with loading, using, modifying and/or developing or reproducing the        #
#  software by the user in light of its specific status of free software,     #
#  that may mean that it is complicated to manipulate, and that also          #
#  therefore means that it is reserved for developers and experienced         #
#  professionals having in-depth computer knowledge. Users are therefore      #
#  encouraged to load and test the software's suitability as regards their    #
#  requirements in conditions enabling the security of their systems and/or   #
#  data to be ensured and, more generally, to use and operate it in the same  #
#  conditions as regards security.                                            #
#                                                                             #
#  The fact that you are presently reading this means that you have had       #
#  knowledge of the CeCILL license and that you accept its terms.             #
#                                                                             #
###############################################################################

package CracTools::DigitagCT::Analyzer::Tiling;

use parent 'CracTools::DigitagCT::Analyzer';

use strict;
use warnings;
use Carp;

=head1 METHODS

=head2 new

  Arg [rna_seq_sam]     : String - RNA-seq SAM file
  Arg [is_stranded] : boolean (Optional)

=cut

sub new {
  my $class = shift;

  # Creating Annotation Analyzer using the generic analyzer
  my $self  = $class->SUPER::new(@_);

  my %args = @_;

  croak "Missing tar_file in arguments" unless defined $args{tar_file};

  $self->_init($args{tar_file});

  return $self;
}

sub _init {
  my $self = shift;
  my $tar_file = shift;

  # Arguments specific to tiling arrays
  my $proximity = 0; # minimun overlap value between tiling and TAG

  print STDERR "> Crossing DGE with Tiling Arrays.\n";
  my $tarh = {};

  # uncompress the TAR file in needed
  if ($tar_file =~/\.gz$/) {
    $tar_file = "gunzip -c $tar_file |";
  } else {
    $tar_file = "<$tar_file";
  }

  open(TAR, $tar_file) or die "Can't read TAR data from file $tar_file";
  while(<TAR>) {
    my @line = split /\t/;
    my $chr = $line[0];
    $chr =~ s/chr//i;
    push @{$tarh->{$chr}{$line[3]}}, $line[1];
    push @{$tarh->{$chr}{$line[3]}}, $line[2];
  }

  my $tag_it = $self->digitagStruct->iterator();
  while (my $tag = $tag_it->()) {
    my $samline = $self->digitagStruct->getSAMLine($tag);  
    my $total = 0;

    my %overlay;
    foreach my $exp (keys %{$tarh->{$samline->chr}}) {

      # search the lowest or identical value
      my $res = bsearchTAR($samline->pos , \@{$tarh->{$samline->chr}{$exp}});
      # calcul overlap in 5': TAG 3'-tiling 5' and in 3': tiling 3'-TAG 5'
      # should be positif if overlap is real
      my ($overlap5, $overlap3) = (0);
      if ($res%2 == 0) {
        # we found a start position, but not necessary a tag inside a TAR
        # test overlap between Tag and TAR
        $overlap5 = $samline->pos + 21 - $tarh->{$samline->chr}{$exp}[$res];
        $overlap3 = $tarh->{$samline->chr}{$exp}[$res+1] - $samline->pos;
        if ($overlap5 > 0 and $overlap3 > 0) {
          # tag inside a tar
          $overlay{$exp}{'overlap'} = 21;
          $overlay{$exp}{'count'}++;
        }
      } elsif ($res >=0){
        # tag between 2 TAR, but can overlap with 3' TAR or 5' TAR
        # TAG 3' - tiling 5'
        $overlap5 = $samline->pos + 21 + $proximity - $tarh->{$samline->chr}{$exp}[$res+1];
        $overlap3 = $tarh->{$samline->chr}{$exp}[$res] - $samline->pos - $proximity;
        if ($overlap5 > 0 or $overlap3 > 0) {
          # we have at lest one overlap
          $overlay{$exp}{'overlap'} = $overlap5>0 ? $overlap5 : $overlap3;
          $overlay{$exp}{'count'}++;
        }					
      }
    }

    if (keys %overlay) {
      foreach my $e (keys %overlay){
        $total += $overlay{$e}{'count'};
      }
    }

    my %tiling_cross;
    $tiling_cross{occ_tiling} = $total;
    $self->digitagStruct->addGenericElement($tag,'tiling_cross',\%tiling_cross);
  }
}

# Binary search, array passed by reference
# search array of string for a given string x
# return index where found or -1 if not found
sub bsearchTAR {
  my ($x, $a) = @_;            # search for x in array a
  my ($l, $u) = (0, @$a - 1);  # lower, upper end of search interval
  my $i;                       # index of probe
  while ($l <= $u) {
    $i = int(($l + $u)/2);
    if ($a->[$i] < $x ) {
      $l = $i+1;
    }
    elsif ($a->[$i] > $x) {
      $u = $i-1;
    } 
    else {
      return $i; # found exact value
    }
  }
  # Not found, get a $i according to some rules
  # return always the lowest value
  if ($x < $a->[$i]) {	
    return $i-1;
  }
  # return the last start TARs and not the last element
  if ($i == @$a - 1) {
    $i--;
  }
  return $i;
}

sub getHeaders {
  my $self = shift;
  my @output;
  return ("occ_tiling");
}

sub getOutput {
  my $self = shift;
  my $tag = shift;
  my $tiling_cross = $self->digitagStruct->getGenericElement($tag,'tiling_cross');
  return ($tiling_cross->{occ_tiling});
}

1;