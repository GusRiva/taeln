xquery version "3.1";

module namespace index="https://digi.ub.uni-heidelberg.de/tools/index";

import module namespace http="http://expath.org/ns/http-client";
import module namespace functx = "http://www.functx.com";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace sparql="http://www.w3.org/2005/sparql-results#";
declare namespace xpath-funct="http://www.w3.org/2005/xpath-functions";
declare namespace skos="http://www.w3.org/2004/02/skos/core#";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:omit-xml-declaration "no";

declare %private variable $index:temp-path as xs:string := "/db/apps/DWorkEditionen/modules/indexGenerator/temp/";


declare function index:create-index($tei-collection as xs:string, 
                                    $output-collection as xs:string, 
                                    $output-file as xs:string, 
                                    $store as xs:boolean, 
                                    $gnd-att as map(), 
                                    $index-root as node()*, 
                                    $structure as node()*, 
                                    $wisski-params as map()){
  (: Main function, which is called in the configuration file. From here all the other functions are called and the index file is created. :)
  
  let $gnd-numbers := index:searchTei($tei-collection, $gnd-att)
 
  let $index-items := 
    for $gnd-num in $gnd-numbers return
      map{"xml": <item>{$structure}</item>, "gnd-num": $gnd-num}
      

  let $new := for $item in  $index-items
  (: We first see if there are any wisski individuals with this GND number, so that we only call index:wisski-find-individual-from-gnd once for each GND number, regardless of how many wisski fields we require    :)  
    let $individual := if ($structure//node()[contains(@origin,"wisski")]) then index:wisski-find-individual-from-gnd($wisski-params, $item?("gnd-num")) else ""
    let $wisski-params := map:put($wisski-params, 'individual', $individual)
    
  (: We pass the gnd number and the wisski parameters to the template function (apply-templates) that then redirects to each endpoint function in order to query and rewrite  :)
    return index:apply-templates($item?("xml")/*, $item?("gnd-num"), $wisski-params)
   
  (: Create the elements from @child :)
   let $new := for $node in $new return index:create-new-children($node)
   
  (: Handle fallback elements   :)
  let $new := for $node in $new return index:fallback($node)
   
  (: Remove "empty" or superfluos elements. Cleaning must be before and after the handling of index:static :)
   let $new := for $node in $new return index:cleaning($node)
   let $new := functx:remove-elements-not-contents($new, 'index:static')
   let $new := for $node in $new return index:cleaning($node)
  (: Processing Instructions     :)
   let $processing1 := <?xml-model href="https://digi.ub.uni-heidelberg.de/schema/tei/heiEDITIONS/tei_hes_index.rng" type="application/xml" schematypens="http://relaxng.org/ns/structure/1.0"?>
   let $processing2 := <?xml-model href="https://digi.ub.uni-heidelberg.de/schema/tei/heiEDITIONS/tei_hes_index.rng" type="application/xml" schematypens="http://purl.oclc.org/dsdl/schematron"?>
   
   let $output-file := if ($output-file ne "") then $output-file else "temp.xml"
   let $base := document{$processing1, $processing2, $index-root}
   
   let $complete := document{for $node in $base/node() return index:insert-content-into-structure($node, $new)}
   
   let $store := if ($store eq true()) then xmldb:store( $output-collection, $output-file, $complete, 'application/xml') else()
   
   return $complete
      
};

declare function index:insert-content-into-structure($nodes as node()*, $new as node()*){
  (: Inserts the completed items  into the element with the @index-data="True" :)
  for $node in $nodes
  return 
    typeswitch($node)
      case text() return $node
      case comment() return $node
      case processing-instruction() return $node
      case element() return  
                      if ($node[@index-data="True"]) 
                          then element {fn:node-name($node)} {($node/@*[local-name() != "index-data"], $new )}
                          else element {fn:node-name($node)} {($node/@*, index:insert-content-into-structure($node/node(), $new))} 
     default return $node 
    
};

declare function index:fallback($nodes as node()*){
  (: Handles the index:fallback in the $structure:)
  for $node in $nodes
  return typeswitch($node)
    case text() return $node

    case element(index:fallback) return if (normalize-space($node/../text()) eq "") then $node/text() else ()

    case element() return element {fn:node-name($node)} 
                           {($node/@*, 
                           index:fallback($node/node())
                           )}   
    default return element {fn:node-name($node)} 
                           {($node/@*, 
                           index:fallback($node/node())
                           )} 
};

declare function index:create-new-children($nodes as node()*){
  (: Handles the @child in the $structure:)
  for $node in $nodes
  return typeswitch($node)
    case text() return $node
    case element() return if (not($node[@child])) 
                      then element {fn:node-name($node)} 
                           {($node/@*, 
                           index:create-new-children($node/node())
                           )} 
                      else element {fn:node-name($node)} 
                           {($node/@*[local-name() != "child"], 
                           element {$node/@child} {$node/text()}
                           )}  
    default return element {fn:node-name($node)} 
                           {($node/@*, 
                           index:create-new-children($node/node())
                           )} 
    
};

declare function index:searchTei($collection as xs:string, $gnd-att){
  (: Searches the TEI files for the ID numbers  :)
  
  (: Transform the sequence of elements into the xpath format required   :)
  let $elements := for $x in $gnd-att?elements return concat("self::", $x)
  let $self-elements := string-join($elements, ' or ')  
  
  let $allvalues := 
    for $el in collection($collection)//node()[$self-elements]
    return data($el/@*[local-name(.) = $gnd-att?attribute])
    
    (: split the raw values from $allvalues at whitespaces 
  and store all the single values in a new sequence variable :)
  let $allsplitvaluessequences :=
    for $value in $allvalues return tokenize($value) 
  
  (: Get all the unique elements  :)
  let $uniquepersons := distinct-values($allsplitvaluessequences)
  (: Apply the regex to get the numbers  :)
  let $all_numbers := 
      for $item in $uniquepersons
      return fn:analyze-string($item, $gnd-att?regex)
  
  (: Return the string of the regex matches that are in this xml structure  :)
  for $match in $all_numbers
  return $match//xpath-funct:match/xpath-funct:group/string()
};


declare function index:apply-templates($nodes as node()*, $gnd-number as xs:string, $wisski-params){
  (: XSLT-like function that changes the instructions written in the $structure variable of the configuration file to the actual result content. 
      The functions passthru and passthruEl are the complement to this function. The first processes text-nodes, the second elements  :)
      
  for $node in $nodes
  return typeswitch($node)
    case text() return index:passthru($node, $gnd-number, $wisski-params)
        
    case element() return index:passthruEl($node, $gnd-number, $wisski-params)
    
    default return element {fn:node-name($node)} 
                           {(
                           index:attributes($node, $gnd-number, $wisski-params), 
                           index:apply-templates($node/node(), $gnd-number, $wisski-params)
                           )}    
};

declare function index:passthru($nodes as node()*, $gnd-number, $wisski-params){
  for $node in $nodes
  return if ($node/..[@origin="gnd"]) then
  if ("!gnd-num" eq normalize-space($node)) then
      $gnd-number
  else index:query-gnd($node, $gnd-number)
    
   else if ($node/..[@origin="wisski"]) then
    if ("!WisskiLink" eq normalize-space($node)) then
      index:wisski-link($wisski-params)
    else index:wisski-main($node, $wisski-params, "text")
  
   else $node
};

declare function index:passthruEl($nodes as node()*, $gnd-number, $wisski-params){
  for $node in $nodes
  return 
    if ($node[@origin="wisski"][@multiple="true"]) 
      then 
      if ("!WisskiLink" eq normalize-space($node/text())) 
        then index:wisski-link($wisski-params)
        else index:wisski-main($node, $wisski-params, "element")
   else element {fn:node-name($node)} 
                           {(
                           index:attributes($node, $gnd-number, $wisski-params), 
                           index:apply-templates($node/node(), $gnd-number, $wisski-params)
                           )}
};

declare function index:attributes($node as node(), $gnd-num, $wisski-params){
  (: This function checks if there are attributes defined for this node using the <attribute> child in the structure definition.
    It returns the original attributes plus these ones, when neccesary
  :)
  
  let $result := 
    if ($node[index:attribute]) 
      then ( $node/@*[local-name() != 'origin' and local-name() != 'sep'], 
            ( for $att in $node/index:attribute
            return attribute {$att/@name} {index:passthruEl($att, $gnd-num, $wisski-params)}  )
            )
    else $node/@*[local-name() != 'origin' and local-name() != 'sep']
  
  return $result
  
};

declare function index:query-gnd($node as node(), $gndnumber){
(:  let $command := $node/text() :)
  let $url := concat('https://digi.ub.uni-heidelberg.de/normdaten/gnd/', $gndnumber)
  
  let $response := http:send-request(<http:request method='get'/>, $url)

  let $result :=
    if ($response[1]/@status = "200") then 
      (: Country and Region  :)
      if (contains(normalize-space($node),'!gnd-country') or contains(normalize-space($node),'!gnd-region')) then 
        let $areacode :=  fn:substring-after(parse-json(util:binary-to-string($response[2]))?('geographicAreaCode')?('@id') , 'gnd-ac:')          
        let $lang := if (contains( $node, '@')) then fn:substring-after($node, '@') else 'de'
        let $area-code-ontology := http:send-request(<http:request method='get'/>, "https://d-nb.info/standards/vocab/gnd/geographic-area-code.rdf")
        return
          if ( matches($areacode, '[^-]+-DE')  ) then
                if (contains(normalize-space($node),'!gnd-region')) then $area-code-ontology//skos:Concept[@rdf:about="https://d-nb.info/standards/vocab/gnd/geographic-area-code#" || $areacode]/skos:prefLabel[@xml:lang=$lang]/text() 
                else if ($lang eq "de" ) then "Deutschland" else if ($lang eq "en" ) then "Germany" else "DE"  
          else if (contains(normalize-space($node),'!gnd-region')) then "" 
                else $area-code-ontology//skos:Concept[@rdf:about="https://d-nb.info/standards/vocab/gnd/geographic-area-code#" || $areacode]/skos:prefLabel[@xml:lang=$lang]/text()
        
    (:   "preferredNameFor"   :)
      else if (normalize-space($node) eq "preferredNameFor") 
        then 
          let $resp-json := parse-json(util:binary-to-string($response[2]))
          let $property := map:keys($resp-json) => (function ($keys) { for $key in $keys where contains($key, 'preferredNameFor') return  $key})()
          return $resp-json?($property)
      (: Dates :)
        else if (contains(normalize-space($node),"dateOf")) 
          then
            let $resp-first := parse-json(util:binary-to-string($response[2]))?(normalize-space($node))
            let $value := $resp-first?('@value')
            let $year := substring-before($value, '-')
            return $year
          
          (: Anything else :)
          else parse-json(util:binary-to-string($response[2]))?(normalize-space($node))             
          
    else ''  

(:  return element {fn:node-name($node)} {( $node/@*[local-name() != 'origin' and local-name() != 'sep'], $result)}:)
  return $result

};

declare function index:wisski-query($query as xs:string, $wisski-params, $result-var-name){
  (: Performs an http request in the triple store and returns a set with the desired value as defined in the query
    $result-var-name: This is the name of the variable after the SELECT query, which should be retrieved
  :)
  
  let $query-enc := encode-for-uri($query)
  let $url := concat($wisski-params?endpoint, $wisski-params?repository, '?query=' , $query-enc)

  (: We retrieve a sparql-results+xml format, which is great for xquery.  :)
  let $response := http:send-request(
              <http:request method='get'>
                <http:header name="Accept" value="application/sparql-results+xml"/>
               </http:request>, $url)
                           
  let $result := $response[2]//sparql:binding[@name=$result-var-name]/*[self::sparql:literal or self::sparql:uri]/string()
  return $result

};

declare function index:wisski-find-individual-from-gnd($wisski-params, $gnd-number){
  (: FIND THE INDIVIDUAL USING THE GND-NUMBER  :)
  let $steps := tokenize($wisski-params?gnd-path, '->')
  
  let $properties := 
      for $step at $p in $steps[position() mod 2 = 0] return
        if ($p eq 1) then concat('?ind ', $step, ' ?O', $p+1, ' . ') 
        else if ($p +1 > count($steps[position() mod 2 = 0])) 
            (: Include the filter to be language tag independent :)
          then concat(' ?O', $p, ' ', $step, '?note . FILTER ( REGEX(STR(?note), "',$gnd-number,'$" ) ) .')
          else concat(' ?O', $p, ' ', $step, ' ?O', $p+1, ' . ') 
  let $classes := 
      for $step at $p in $steps[position() mod 2 = 1] return
        if ($p eq 1) then (concat(' ?ind rdf:type ', xs:string($steps[1]), ' . ')) else concat('?O', $p, ' rdf:type ', $step, ' . ')
        
  let $center-query := for $i in 1 to count($properties)
                  return concat($classes[$i], $properties[$i])
  
  let $individual-query := concat($wisski-params?prefixes, ' SELECT DISTINCT ?ind WHERE { ', string-join($center-query, ' '), ' }')

   

  let $individual-found := index:wisski-query($individual-query, $wisski-params, "ind")
 
  let $individual := concat("<", $individual-found, '>')
  return $individual
 
};

declare function index:wisski-main($node as node(), $wisski-params, $type as xs:string){
  
  let $individual := $wisski-params?individual
   
  (: FROM THE INDIVIDUAL TO THE SEARCHED INFORMATION. If none found, then just return the element  :)
  return if ($individual eq "<>" or $individual eq "") then  "" 
  else
 
  let $sep := if ($node/..[@sep]) then $node/../@sep else ''
 
  (: This is a tricky bit: we divide the instructions from the pathbuilder structure (with ->, $content) into properties and classes and write the corresponding lines of the query. The $p (position) is very important to define the variables in the sparql query, which are ?O1, ?O2, etc. In $center-query we put the lines for classes and properties back together in the correct order. :)
  
    
  let $steps := if ($type eq 'element') then tokenize($node/text(), '->') else tokenize($node, '->')
  let $properties := 
      for $step at $p in $steps[position() mod 2 = 0] return
        if ($p eq 1) then concat($individual, ' ', $step, ' ?O', $p+1, ' . ') else (concat(' ?O', $p, ' ', $step, ' ?O', $p+1, ' . ') )
  let $classes := 
      for $step at $p in $steps[position() mod 2 = 1] return
        if ($p eq 1) then (concat($individual, ' rdf:type ', xs:string($steps[1]), ' . ')) else concat('?O', $p, ' rdf:type ', $step, ' . ')
          
  let $center-query := for $i in 1 to count($properties)
                  return if ($i eq 1) then $properties[$i] else concat($classes[$i], $properties[$i])
  
  (: We are looking for the variable of the sparql with the highest number, which is the last written in $properties, so it's the highest $p + 1  :)
  let $result-var-name := concat("O", count($properties) + 1)
  
  let $query := concat($wisski-params?prefixes, ' SELECT DISTINCT ?',$result-var-name ,' WHERE { ', string-join($center-query, ' ') ,' }') 
   
  let $result :=  index:wisski-query($query, $wisski-params, $result-var-name)
  
  return if ($type eq 'element') 
    then for $treffer in $result return element {fn:node-name($node)} {$node/@*[local-name() != 'origin'][local-name() != 'multiple'], $treffer } 
    else string-join($result, $sep )
  
};

declare function index:wisski-link($wisski-params as map()){
  let $individual := $wisski-params?individual
  return if ($individual eq "<>" or $individual eq "") then  "" 
  else 
    let $query :=  concat($wisski-params?prefixes, ' SELECT ?url WHERE { ', $individual ,' owl:sameAs ?url . ?url ?origFrom "drupal_id"}')
    let $result := index:wisski-query($query, $wisski-params, "url")
    return $result
};

declare function index:cleaning($nodes as node()*){
  (: Remove empty elements, or elements with only index:static content, or where the relevant attribute was not created  :)
  for $node in $nodes
  return typeswitch($node)
    case text() return $node
    case element(index:attribute) return ()
    case element() return 
            if (not(matches($node/string(), '[\w\d]+'))) 
            then 
              ()
            else
              if (not($node[index:static or index:attribute]))
              then element {fn:node-name($node)} {($node/@*, index:cleaning($node/node()))}
              else 
                 if (matches($node/text(),'[\w\d]+' ))
                 then element {fn:node-name($node)} {($node/@*, index:cleaning($node/node()))}
                 else 
                    if ($node//index:attribute/text())
                    then element {fn:node-name($node)} {($node/@*, index:cleaning($node/node()))}
                    else 
                     if (not($node/index:static[@keepWhen]))
                     then ()
                     else
                       let $var-name := $node/index:static/@keepWhen
                       return 
                       if (matches($var-name, '@\w+')) then
                         if (string-length($node/@*[local-name() = substring($var-name, 2)]) > 0)
                         then element {fn:node-name($node)} {($node/@*, index:cleaning($node/node()))}
                         else ()
                       else() (:In case of keepWhen for some other condition, not yet neccesary:)
            
    default return element {fn:node-name($node)} 
                           {($node/@*, 
                           index:cleaning($node/node())
                           )}
};
