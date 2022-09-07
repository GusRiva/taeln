xquery version "3.1";
(: See https://gitlab.ub.uni-heidelberg.de/editions/heieditions-index for more information :)

import module namespace index="https://digi.ub.uni-heidelberg.de/tools/index" at "/db/apps/DWorkEditionen/modules/indexGenerator/index.xqm";

declare namespace output="http://www.w3.org/2010/xslt-query-serialization";

declare option exist:serialize "omit-xml-declaration=no encoding=utf-8 indent=yes";



let $output-collection := "/db/resources/projects/myProject/index/pers/"
let $output-file:= "myProjectPersons.xml"
let $store := false()

let $tei-collection := "/db/resources/projects/Duerer/semantic"

let $gnd-att := map{
    "elements" : ("tei:persName", "tei:rs"),
    "attribute" : "ref",
    "regex": "pers:gnd-(\S+)"
    }

let $wisski-endpoint := "http://lod.ub.uni-heidelberg.de:7200/repositories/"
let $wisski-repository := "duerer02"

let $wisski-prefixes := "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
                         PREFIX owl: <http://www.w3.org/2002/07/owl#>
                         PREFIX ecrm: <http://erlangen-crm.org/200717/>
                         PREFIX wvz: <http://lod.ub.uni-heidelberg.de/ontologies/werkverzeichnis/>
                         PREFIX duerer: <http://lod.ub.uni-heidelberg.de/data/duerer/>"

let $wisski-gnd-path := "ecrm:E21_Person -> ecrm:P48_has_preferred_identifier -> wvz:WV42_Authority_Document_ID -> ecrm:P139_has_alternative_form -> wvz:WV42_URI -> ecrm:P3_has_note"

let $index-root := <TEI xmlns="http://www.tei-c.org/ns/1.0">
   <teiHeader>
   <title></title>
   </teiHeader>
   <text ana='hc:IndexOfPersons'>
      <body>
         <listPerson index-data="True">
         </listPerson>
      </body>
   </text>
</TEI>

(: Simple example with gnd:)
let $structure := <person xmlns="http://www.tei-c.org/ns/1.0">
  <names>
    <prefName ana="hc:something" origin="gnd">preferredNameForThePerson</prefName>
  </names>
</person>

(:More complex example:)
let $structure := <person xmlns="http://www.tei-c.org/ns/1.0">
  <names>
    <prefName ana="hc:something" origin="wisski">ecrm:E21_Person -> ecrm:P1_is_identified_by -> ecrm:E41_Appellation -> ecrm:P3_has_note</prefName>
  </names>
  <note origin="wisski">
    <index:static>Bezug zu Dürer: </index:static>
    ecrm:E21_Person -> ecrm:P129i_is_subject_of -> wvz:WV33_Comment -> ecrm:P3_has_note
    <index:static>.</index:static>
  </note>
  <birth>
    <note origin="wisski">ecrm:E21_Person -> ecrm:P98i_was_born -> ecrm:E67_Birth -> ecrm:P4_has_time-span -> ecrm:E52_Time-Span -> ecrm:P3_has_note</note>
  </birth>
  <death origin="wisski" child="note">
    ecrm:E21_Person -> ecrm:P100i_died_in -> ecrm:E69_Death -> ecrm:P4_has_time-span -> ecrm:E52_Time-Span -> ecrm:P3_has_note
  </death>
  <occupation>
    <note origin="wisski" sep=", ">ecrm:E21_Person -> ecrm:P11i_participated_in -> wvz:WV7_Occupation -> ecrm:P2_has_type -> wvz:WV55_Role -> ecrm:P1_is_identified_by -> ecrm:E41_Appellation -> ecrm:P3_has_note</note>
  </occupation>
  <occupation2 multiple="true" origin="wisski" child="note">
    ecrm:E21_Person -> ecrm:P11i_participated_in -> wvz:WV7_Occupation -> ecrm:P2_has_type -> wvz:WV55_Role -> ecrm:P1_is_identified_by -> ecrm:E41_Appellation -> ecrm:P3_has_note
  </occupation2>
  <idno origin="gnd">!gnd-num</idno>
  <listRef>
    <ref ana="hc:URLReference"><index:static keepWhen="@target">Link zu Wisski</index:static>
      <index:attribute origin="wisski" name="target">!WisskiLink</index:attribute>
    </ref>
  </listRef>
</person>





let $wisski-params := map {
  "endpoint": $wisski-endpoint,
  "prefixes": $wisski-prefixes,
  "repository": $wisski-repository,
  "gnd-path": $wisski-gnd-path
    }

let $result := index:create-index($tei-collection, $output-collection, $output-file, $gnd-att, $index-root, $structure, $wisski-params)
 

return $result
