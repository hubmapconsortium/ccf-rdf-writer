# CCF RDF Writer

From a set of terms, generate a graph and a RDF file (nt) with all inferred `part of` relationships.

## Running using Docker

First, please create folder called `tmp` to include the temporary files generated during the pipeline.

To generalise this pipeline make sure you pass values to the two parameters `ORGAN` and `ORGAN_ONTOLOGY`. 
Also call goal using same value passed to `ORGAN`, e.g., `make graph/lung-extended.png` or `make graph/kidney-extended.png`

Complete call would be:

```
sh run.sh make graph/kidney-extended.png ORGAN=kidney ORGAN_ONTOLOGY=master/owl/ccf_Kidney_classes.owl
```

The RDF file is `ccf-{organ}-extended.nt`

## Without Docker

Need to install the following dependencies:

1. ROBOT - http://robot.obolibrary.org/
2. relation-graph - https://github.com/balhoff/relation-graph/
3. Soufflé - https://souffle-lang.github.io/index.html
4. og2dot.js - https://github.com/cmungall/obographviz
5. dot - https://graphviz.org
