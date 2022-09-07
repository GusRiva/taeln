# TAELN

TEI Automatic Enriched List of Names (TAELN)​: An XQuery-based Open Source Solution for the Automatic Creation of Indexes from TEI and RDF Data

This is an open source tool written in XQuery that enables the creation of TEI indexes using a flexible custom templating language. It uses the ids according to one authority document to create a file for an index with information from one or more RDF endpoints.  

TAELN has been developed for the edition of texts from Albrecht Dürer and his family. People, places and works of art are identified with GND-numbers in the TEI edition. The indexes generated include some information from GND records, but mostly from duerer.online, a virtual research portal, created with WissKI, which includes an RDF endpoint. 

TAELN relies on XML-templates to indicate the information to retrieve from the different endpoints as well as how to structure the desired TEI output. They use a straight-forward but flexible and powerful syntax described below. 

At the moment, the script is able to retrieve data from the GND and from a wissKI endpoint (or any open endpoint using the RDF4J API)

## Requirements

The current version is designed to work with [eXistDB](http://exist-db.org/exist/apps/homepage/index.html) and you need to feel confortable opening and editing xQuery files that work as configuration files.

## Files

index.xqm is the main file of the module where all the required functions are defined.

For each index to be created an xquery file following the template in indexExample.xql must be created. This file imports index.xqm and defines the required variables. To generate the index file, just open this file in eXist.

A posible structure in eXist might be:

```
db
└───apps
    └───apps
        └───DWorkEditionen
            └───modules
                └───indexGenerator
                    │  index.xqm
                    │
                    └───myProject
                    │   │  index_myProject_pers.xql
                    │   │  index_myProject_place.xql
                    │   │  index_myProject_title.xql
                    │
                    └───otherProject
                        │  index_otherProject_pers.xql
                        │  index_otherProject_place.xql
                        │  index_otherProject_title.xql

```

Make sure that the .xql files import the index.xqm correctly (you need to define the path when importing the module in namespaec *index*).

## Erklärung zur Konfigurationsdatei

### Variables

  **$output-collection**: Where the index file will be created. $store must be set to true()
  
  **$output-file**: The name of the index file that will be created. $store must be set to true()

  **$store**: Boolean true() or false(). Whether the result should be stored in a file or not, for example, if we just want to test or send it to another application in a pipeline, we can use false().
  
  **$tei-collection**: The path to the collection of the TEI files in eXist
  
  **$gnd-att**: How to find the gnd-numbers in the elements of the TEI files. It is a map with three keys:


    "elements" : Sequence of elements in which to search. Include prefixes. Example ("tei:persName", "tei:rs"),
    "attribute" : The attribute in which to find the numbers, example "ref",           
    "regex": The regex we need to use to parse the value of the attribute to retrieve the gnd numbers. Must have one capturing group for the numbers. Example "pers:gnd-([\S]+)"



  **$wisski-endpoint**: The endpoint to perform the sparql-queries. (wisski only)

  **$wisski-repository**: the id of the repository in the triple store for wisski queries, example: duerer02 (wisski only)

  **$wisski-prefixes**: Prefixes to use in the paths and queries for the wisski Triplestore. (wisski only)

  **$wisski-gnd-path**: Path from the entity to the gnd-number as defined in wisski Pathbuilder. String using prefixes each step separated by -> 
  (wisski only)
  
  **$index-root**: The structure for the root of the index. The list of items will replace the element with the attribute index-data="True".
  
  **$structure**: Defines the structure of each entry in the index. All elements will be produced in the final result with the TEI prefix. Detailed explanation below.


### Structure 
    
#### Fetching information from an endpoint into an element 

Each element to be completed with information from gnd or wisski must have the @origin="gnd|wisski". All attributes that don't include processing instruction for the script (see below, @sep, @multiple, @child) will be included in the output. That means we can include the @ana or @type attributes we want to see in the output. The content of an element to be completed is different in case of gnd and wisski:

1. **gnd**: we include the key in the json response we are looking for, for example "preferredNameForThePerson" or an attribute, "@type". See below for more details about preferredNameFor.

2. **wisski**: we write the path from the Pathbuilder of the field from which we want to retrieve the information. Each step is divided by dash and arrow ( -> ) and must use prefixes. This can be copied from the wisski Pathbuilder directly. Usually we might need to add the data property at the end of the path, which is not shown in the wisski Pathbuilder. The exception to this rule is when we want to fetch the wisski-link for an entity ([s.below](#special-keywords)).

#### Fetching information from an endpoint into an attribute

To write attributes with value programmatically, we use the element `index:attribute` as a child of the element for which we want to write the attribute. We use the `@origin` and the textual content just as if we were fetching information for an element ([s. above](#fetching-information-from-an-endpoint-into-an-element)). We must also include the attribute `@name`, to define the name of the attribute to be created. 

#### Fetching the same information from multiple endpoints and creating a priority

We can ask for the content of one element to be fetched from one endpoint, and only in case nothing was found to try from another. (this is not really what happens: we fetch the information from both and then keep only the top priority one). For this we use index:fallback as a child of the relevant element. Attributes and content follow the rules of a normal element (@origin etc.)

Example: 
```
<persName origin="wisski">ecrm:E21_Person -> ecrm:P1_is_identified_by -> ecrm:E41_Appellation -> ecrm:P3_has_note
    <index:fallback origin="gnd">preferredNameForThePerson</index:fallback>
</persName>
```

#### Mixed static and programmatical content

To include static content in the body of an element or attribute that needs to fetch information from an endpoint, use the element `index:static`. This element will be deleted if there is no other text content in the parent element, unless it has the `@keepWhen` pointing to an attribute in the parent element. Example: `keepWhen="@target"`. This is useful when you want to create an element that has a static text and a programmatical attribute, for example, the link to WissKi: 

```
<ref ana="hc:URLReference">
  <index:static keepWhen="@target">Link zu Wisski</index:static>
  <index:attribute origin="wisski" name="target">!WisskiLink</index:attribute>
</ref>
```

#### Special keywords

1. **!gnd-num**  The gnd number will be copied there. The element must have the origin="gnd" attribute.
2. **!gnd-country** The country of a Place in the GND will be copied here. The element must have the origin="gnd" attribute.
3. **!gnd-region** The GND identifies the *Bundesland* for places within Germany. This field only works for those places. The element must have the origin="gnd" attribute.
4. **preferredNameFor** The GND has many properties for the preferred name, depending of the class of the individual (person, place, etc.). If we use "preferredNameFor" the corresponding one for the class will be used instead of having to know exactly which one.
5. **!WisskiLink**      This keywork is replaced by the link to the /view/ page in wisski. The element must have the origin="wisski" attribute.

#### Special Attributes

1. `@sep` and `@multiple`: In case the field can have **multiple elements** we can use one of these options (mutually incompatible).

**sep** : Defines a separator to divide the items in the field, for example comma or dot.

**multiple="true"** : The element will be repeated for each value.

2. `@child` should be used when we don't want to write the fetched value directly as a text node, but in a child node. For example:

```
<birth origin="wisski" child="note">
  ecrm:E21_Person -> ecrm:P98i_was_born -> ecrm:E67_Birth -> ecrm:P3_has_note
</birth>
```

would result in entries like this:

```
<birth>
  <note>1922</note>
</birth>
```

We can combine these attributes to achieve complex results. For example:

```
<occupation multiple="true" origin="wisski" child="note">
  ecrm:E21_Person -> ecrm:P11i_participated_in -> wvz:WV7_Occupation -> ecrm:P3_has_note
</occupation>
```

Could create results like these:
```
<occupation>
  <note>Sammler</note>
</occupation>
<occupation>
  <note>Forscher</note>
</occupation>
```
