###############################################################################
#                                                                             #
#    Copyright © 2012-2013 -- IRB/INSERM                                      #
#                            (Institut de Recherche en Biothérapie /          #
#                             Institut National de la Santé et de la          #
#                             Recherche Médicale)                             #
#                                                                             #
#  Auteurs/Authors:  Jerôme AUDOUX <jerome.audoux@univ-montp2.fr>             #
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

package CracTools::DigitagCT::Analyzer::Annotation;

use parent 'CracTools::DigitagCT::Analyzer';

use strict;
use warnings;
use Carp;

# load Cractools-core modules
use CracTools::Utils;
use CracTools::Annotator;
use CracTools::DigitagCT::Const;

our @type_annot = ('3PRIM_UTR_sense','CDS_sense','5PRIM_UTR_sense','EXON_sense','EXON_antisense','INXON_sense','INTRON_sense','3PRIM_UTR_antisense','CDS_antisense','5PRIM_UTR_antisense','INXON_antisense','INTRON_antisense','INTER_PROXIMAL','INTER_DISTAL');

#our @type_non_coding = ('small_ncRNA','other_lncRNA','lincRNA','other_noncodingRNA');
our @type_non_coding = ();

=head1 METHODS

=head2 new

  Arg [gff_file]    : String - GFF file to perform annotation with
  Arg [est_file]    : String (Optional) - GFF file with EST to find annotation if none
                      have been found in the 

  Example     : my $annotation = CracTools::GFF::Annotation->new(gff_file => $gff);
  Description : Create a new CracTools::ChimCT::Analyzer::Annotation object
  ReturnType  : CracTools::ChimCT::Analyzer::Annotation
  Exceptions  : none

=cut

sub new {
  my $class = shift;

  # Creating Annotation Analyzer using the generic analyzer
  my $self  = $class->SUPER::new(@_);

  my %args = @_;

  croak "Missing gff_file in arguments" unless defined $args{gff_file};

  $self->_init($args{gff_file},$args{est_file});

  return $self;
}

sub _init {
  my $self = shift;
  my $gff_file = shift;
  my $est_file = shift;

  # Loading constants
  my $dge_tag_length = $CracTools::DigitagCT::Const::DGE_TAG_LENGTH;

  # Builing the tool to perform annotation
  my $annotator = CracTools::Annotator->new($gff_file);
  my $annotator_est;
  if(defined $est_file) {
    $annotator_est = CracTools::Annotator->new($est_file);
  }

  my $tag_it = $self->digitagStruct->iterator();
  while (my $tag = $tag_it->()) {
    my %annotation;
    my $samline = $self->digitagStruct->getSAMLine($tag);  

    my ($start,$end);
    $start = $samline->pos;
    $end = $start + $dge_tag_length;

    my ($annot_coding,$priority_coding,$type_coding) = $annotator->getBestAnnotationCandidate($samline->rname,$start,$end,$samline->getStrand,\&getCandidateCodingPriority); 

    # We look to the opposite strand if no annotations have been found
    if(!defined $annot_coding) {
      ($annot_coding,$priority_coding,$type_coding) = $annotator->getBestAnnotationCandidate($samline->rname,$start,$end,$samline->getStrand*-1,\&getCandidateCodingPriority); 
      if(defined $type_coding) {
        $type_coding .= '_antisense';
      }
    } else {
      $type_coding .= '_sense';
    }

    # If there is still nothing and est_file is defined
    if(!defined $annot_coding) {
      if($samline->getStrand == 1) {
        ($annot_coding,$priority_coding,$type_coding) = $annotator->getBestAnnotationCandidate($samline->rname,$start-$CracTools::DigitagCT::Const::INTERGENIC_THRESHOLD,$end,$samline->getStrand,\&priorityNeighborhoodLeft); 
      } else {
        ($annot_coding,$priority_coding,$type_coding) = $annotator->getBestAnnotationCandidate($samline->rname,$start,$end+$CracTools::DigitagCT::Const::INTERGENIC_THRESHOLD,$samline->getStrand,\&priorityNeighborhoodRight); 
      }
      #if(defined $priority_coding && $priority_coding < $CracTools::DigitagCT::Const::INTERGENIC_THRESHOLD) {
      if(defined $priority_coding) {
        $type_coding = "INTER_PROXIMAL";
      } else {
        $type_coding = "INTER_DISTAL";
        # LOOKING FOR EST ON GOOD STRAND
        if(defined $annotator_est) {
          my ($annot_est,$priority_est,$type_est) = $annotator_est->getBestAnnotationCandidate($samline->rname,$start,$end,$samline->getStrand,\&getCandidateCodingPriority); 
          if(defined $annot_est) {
            $annotation{est_gene} = $annot_est->{gene}->attribute('ID');
          }
        }
      }
    }

    if(defined $annot_coding) {
      $annotation{coding_hugo} = $annot_coding->{gene}->attribute('Name');
      $annotation{coding_description} = $annot_coding->{mRNA}->attribute('type');
      $annotation{coding_id} = $annot_coding->{gene}->attribute('ID');
    }

    $annotation{coding_annotation} = $type_coding;

    # NON-coding annotation
    my ($annot_non_coding,$priority_non_coding,$type_non_coding) = $annotator->getBestAnnotationCandidate($samline->rname,$start,$end,$samline->getStrand,\&getCandidateNonCodingPriority); 
    if(defined $annot_non_coding) {
      $annotation{non_coding_hugo} = $annot_non_coding->{gene}->attribute('Name');
      $annotation{non_coding_description} = $annot_non_coding->{mRNA}->attribute('type');
      $annotation{non_coding_id} = $annot_non_coding->{gene}->attribute('ID');
      my ($main_type_non_coding) = $annotation{non_coding_description} =~ /(\S+):\S+/;
      unless($main_type_non_coding ~~ @type_non_coding) {
        push @type_non_coding, $main_type_non_coding;
      }
    }

    $self->digitagStruct->addGenericElement($tag,'annotation',\%annotation);
  }

}

sub getHeaders {
  my $self = shift;
  my @output;
  @output = ("tag_annotation",
    "gene_hugo",
    "gene_description",
    "gene_id",
    "chromosome",
    "location",
    "tag_strand",
    "non_coding_hugo",
    "non_coding_description",
    "non_coding_id",
    #"gene_hugo_5PRIM",
    #"gene_description_5PRIM",
    #"gene_id_5PRIM",
    #"distance_of_5PRIM_gene",
    #"gene_hugo_3PRIM",
    #"gene_description_3PRIM",
    #"gene_id_3PRIM",
    #"distance_of_3PRIM_gene"
    );
  return @output;
}

sub getOutput($) {
  my $self = shift;
  my $tag = shift;
  my @output;
  my $samline = $self->digitagStruct->getSAMLine($tag);  
  my $annot = $self->digitagStruct->getGenericElement($tag,'annotation');
  my $coding_desc;
  if(defined $annot->{coding_description}) {
    ($coding_desc) = split(":",$annot->{coding_description});
  }

  @output = (
    $annot->{coding_annotation},
    $annot->{coding_hugo},
    $coding_desc,
    $annot->{coding_id},
    $samline->rname,
    $samline->pos,
    $samline->getStrand,
    $annot->{non_coding_hugo},
    $annot->{non_coding_description},
    $annot->{non_coding_id},
    #$annot{hugo_5prim},
    #$annot{desc_5prim},
    #$annot{id_5prim},
    #$annot{distance_of_5prim_gene},
    #$annot{hugo_3prim},
    #$annot{desc_3prim},
    #$annot{id_3prim},
    #$annot{distance_of_3prim_gene}
    );
  return (@output);
}

sub getAnnotationSummary {
  my $self = shift;
  # Load arguments relative to annotation :
  my $annotation_stats_non_coding_threshold = $CracTools::DigitagCT::Const::ANNOTATION_STATS_NON_CODING_THRESHOLD;
  my $summary = "";
  my ($totalTag,$totalOcc,$totalTagNonCoding,$totalOccNonCoding) = (0,0,0,0);
  my (%hashProt,%hashProtByCat,%hashNonCoding,%hashNonCodingByCat,%hashNonCodingByProt) = ((),(),(),(),());

  my $tag_it = $self->digitagStruct->iterator();
  while (my $tag = $tag_it->()) {
    my $samline = $self->digitagStruct->getSAMLine($tag);  
    my %annotation = %{$self->digitagStruct->getGenericElement($tag,'annotation')};
    my ($proteinClassif,$nonCodingClassif,$occ) = ($annotation{coding_annotation},$annotation{non_coding_description},$self->digitagStruct->nbOccurences($tag));
    if(!defined $nonCodingClassif) {
      $nonCodingClassif = $CracTools::DigitagCT::Const::NOT_AVAILABLE;
    }

    $totalOcc += $occ;
    $totalTag++;

    $hashProt{$proteinClassif}{'TAG'} +=1;
    $hashProt{$proteinClassif}{'OCC'} +=$occ;
    if ($nonCodingClassif !~ /$CracTools::DigitagCT::Const::NOT_AVAILABLE/i && ($occ <= $annotation_stats_non_coding_threshold)){
      ($nonCodingClassif) = $nonCodingClassif =~ /(\S+):\S+/;
      $totalTagNonCoding += 1;
      $totalOccNonCoding += $occ;
      $hashNonCoding{$nonCodingClassif}{'TAG'} += 1;
      $hashNonCoding{$nonCodingClassif}{'OCC'} += $occ;
      $hashNonCodingByCat{$proteinClassif}{$nonCodingClassif}{'TAG'} +=1;
      $hashNonCodingByCat{$proteinClassif}{$nonCodingClassif}{'OCC'} +=$occ;
      $hashNonCodingByProt{$proteinClassif}{'TAG'} +=1;
      $hashNonCodingByProt{$proteinClassif}{'OCC'} +=$occ;
      $hashProtByCat{$nonCodingClassif}{$proteinClassif}{'TAG'} +=1;
      $hashProtByCat{$nonCodingClassif}{$proteinClassif}{'OCC'} +=$occ;
    }
  }

  $summary .= "
  ------------------------------------------------------------------------------------------------------
    (process A)      Distribution of transcripts annotation and expression level on the genome                 
  ------------------------------------------------------------------------------------------------------

  "; 

  $summary .= "totalTag: $totalTag\n\n"; 
  $summary .= "type\tnumber\tpercent\n";     
  foreach my $key (@type_annot){
    if(defined $hashProt{$key}{'TAG'}) {
      my $percent = $hashProt{$key}{'TAG'}*100/$totalTag;
      $summary .= "$key\t".$hashProt{$key}{'TAG'}."\t".$percent."\n";
    } else {
      $summary .= "$key\t0\t0\n";
    }
  }  

  $summary .= "\n                          ------------------------                              \n";

  $summary .= "\n\ntotalOcc: $totalOcc\n\n"; 
  $summary .= "type\tnumber\tpercent\n";
  foreach my $key (@type_annot){
    if(defined $hashProt{$key}{'OCC'}) {
      my $percent = $hashProt{$key}{'OCC'}*100/$totalOcc;
      $summary .= "$key\t".$hashProt{$key}{'OCC'}."\t".$percent."\n";
    } else {
      $summary .= "$key\t0\t0\n";
    }
  }  

  $summary .= "\n";

  $summary .= "
  ------------------------------------------------------------------------------------------------------
   (process B)   Distribution of transcripts annotation among the non-coding transcripts 
  ------------------------------------------------------------------------------------------------------

  "; 
  $summary .= "totalTagNonCoding: $totalTagNonCoding\n\n";
  $summary .= "type\tnumber\tpercent\n";     
  foreach my $key (@type_annot){
    if (defined $hashNonCodingByProt{$key}{'TAG'}){
      my $percentTag = $hashNonCodingByProt{$key}{'TAG'}*100/$totalTagNonCoding;
      $summary .= "$key\t".$hashNonCodingByProt{$key}{'TAG'}."\t$percentTag\n";
    } else {
      $summary .= "$key\t0\t0\n";
    }
  }
  $summary .= "\n                          ------------------------                              \n";
  $summary .= "\n\ntotalOccNonCoding: $totalOccNonCoding\n\n";
  $summary .= "type\tnumber\tpercent\n"; 
  foreach my $key (@type_annot){
    if (defined $hashNonCodingByProt{$key}{'OCC'}){
      my $percentOcc = $hashNonCodingByProt{$key}{'OCC'}*100/$totalOccNonCoding;
      $summary .= "$key\t".$hashNonCodingByProt{$key}{'OCC'}."\t$percentOcc\n";
    } else {
      $summary .= "$key\t0\t0\n";
    }
  }   
  $summary .= "\n";

  $summary .= "
  ------------------------------------------------------------------------------------------------------
   (process C)   Distribution of non-coding transcripts among the transcripts annotation
  ------------------------------------------------------------------------------------------------------

  "; 

  $summary .= "\n\ntotalTag: $totalTag\n\n"; 
  $summary .= "type";
  
  foreach my $type_nc (@type_non_coding){
    $summary .= "\t$type_nc"; 
  }
  $summary .= "\n";
      
  foreach my $key (@type_annot){
    $summary .= "$key";
    foreach my $key2 (@type_non_coding){
      if (defined $hashNonCodingByCat{$key}{$key2}{'TAG'}){
        my $percentTag = $hashNonCodingByCat{$key}{$key2}{'TAG'}*100/$hashProt{$key}{'TAG'};
        $summary .= "\t$percentTag";
      }else{
        $summary .= "\t0";
      }
    }
    $summary .= "\n";
  }
  $summary .= "\n                          ------------------------                              \n";
  $summary .= "\n\ntotalOcc: $totalOcc\n\n"; 
  foreach my $key (@type_annot){
    $summary .= "$key";
    foreach my $key2 (@type_non_coding){
      if (defined $hashNonCodingByCat{$key}{$key2}{'OCC'}){
        my $percentOcc = $hashNonCodingByCat{$key}{$key2}{'OCC'}*100/$hashProt{$key}{'OCC'};
        $summary .= "\t$percentOcc";
      }else{
        $summary .= "\t0";
      }
    }
    $summary .= "\n";
  }  
  $summary .= "\n";

  $summary .= "
  ------------------------------------------------------------------------------------------------------
    (process D)      Distribution of non-coding transcripts and expression level on the genome                 
  ------------------------------------------------------------------------------------------------------

  "; 
  $summary .= "totalTagNonCoding: $totalTagNonCoding\n\n";
  $summary .= "type\tnumber\tpercent\n"; 
  foreach my $key (@type_non_coding){
    if (defined $hashNonCoding{$key}{'TAG'}){
      my $percent = $hashNonCoding{$key}{'TAG'}*100/$totalTagNonCoding;
      $summary .= "$key\t".$hashNonCoding{$key}{'TAG'}."\t".$percent."\n";
    } else {
      $summary .= "$key\t0\t0\n";
    }
  }  
  $summary .= "\n                          ------------------------                              \n";
  $summary .= "\n\ntotalOccNonCoding: $totalOccNonCoding\n\n"; 
  foreach my $key (@type_non_coding){
    if (defined $hashNonCoding{$key}{'OCC'}){
      my $percent = $hashNonCoding{$key}{'OCC'}*100/$totalOccNonCoding;
      $summary .= "$key\t".$hashNonCoding{$key}{'OCC'}."\t".$percent."\n";
    } else {
      $summary .= "$key\t0\t0\n";
    }
  }  
  $summary .= "\n";
  return $summary;
}


=head2 getCandidateCodingPriority

  Arg [1] : String - pos_start
  Arg [2] : String - pos_end
  Arg [3] : hash - candidate

  Description : Method used to give a priority to a candidate in CracTools;:Annotator
                The best priority is 0. A priority of -1 means that this candidate
                should be avoided.
  ReturnType  : ($priority,$type)

=cut

sub getCandidateCodingPriority {
  my ($pos_start,$pos_end,$candidate) = @_;
  my ($priority,$type) = (-1,'');
  my ($mRNA,$exon) = ($candidate->{mRNA},$candidate->{exon});
  if(defined $mRNA && $mRNA->attribute('type') =~ /protein_coding/i) {
    if(defined $exon) {
      if($exon->start <= $pos_start || $exon->end >= $pos_end) {
        if(defined $candidate->{three}) {
          $type = '3PRIM_UTR';
          $priority = 1;
        } elsif(defined $candidate->{five}) {
          $type = '5PRIM_UTR';
          $priority = 3;
        } elsif(defined $candidate->{cds}) {
          $type = 'CDS';
          $priority = 2;
        } else {
          $type = 'EXON';
          $priority = 4;
        }
      } else {
        $priority = 5;
        $type = 'INXON';
      }
    } else {
        $priority = 6;
        $type = 'INTRON';
    }
  }
  return ($priority,$type);
}

=head2 getCandidateNonCodingPriority

  Arg [1] : String - pos_start
  Arg [2] : String - pos_end
  Arg [3] : hash - candidate

  Description : Method used to give a priority to a candidate in CracTools;:Annotator
                The best priority is 0. A priority of -1 means that this candidate
                should be avoided.
  ReturnType  : ($priority,$type)

=cut

sub getCandidateNonCodingPriority {
  my ($pos_start,$pos_end,$candidate) = @_;
  my ($priority,$type) = (-1,'');
  my ($mRNA,$exon) = ($candidate->{mRNA},$candidate->{exon});
  if(defined $mRNA && $mRNA->attribute('type') !~ /protein_coding/i) {
    if(defined $exon) {
      if($exon->start <= $pos_start || $exon->end >= $pos_end) {
        $type = 'NON_CODING';
        $priority = 1;
      }
    }
  }
  return ($priority,$type);
}

sub priorityNeighborhoodLeft {
  my ($pos_start,$pos_end,$candidate) = @_;
  my ($priority,$type) = (-1,'');
  my $mRNA = $candidate->{mRNA};
  my $gene = $candidate->{gene};
  if(defined $mRNA && $mRNA->attribute('type') =~ /protein_coding/i) {
    $priority = $pos_start - $gene->end;
    $type = 'LEFT_NEIGHBORHOOD';
  }
  return ($priority,$type);
}

sub priorityNeighborhoodRight {
  my ($pos_start,$pos_end,$candidate) = @_;
  my ($priority,$type) = (-1,'');
  my $mRNA = $candidate->{mRNA};
  my $gene = $candidate->{gene};
  if(defined $mRNA && $mRNA->attribute('type') =~ /protein_coding/i) {
    $priority = $gene->start - $pos_end;
    $type = 'RIGHT_NEIGHBORHOOD';
  }
  return ($priority,$type);
}

1;
