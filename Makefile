ROBOT_ENV=ROBOT_JAVA_ARGS=-Xmx30G
ROBOT=$(ROBOT_ENV) robot
RG_ENV=JAVA_OPTS=-Xmx30G
RG=$(RG_ENV) relation-graph

SCATLAS_KEEPRELATIONS = relations.txt

## To generalise this pipeline make sure you pass values to the two parameters ORGAN and ORGAN_ONTOLOGY. 
## Also call goal using same value passed to ORGAN, e.g., make graph/lung-extended.png or make graph/kidney-extended.png
## Complete call would be: (sh run.sh) make graph/kidney-extended.png ORGAN=kidney ORGAN_ONTOLOGY=master/owl/ccf_Kidney_classes.owl

# ORGAN = lung
# ORGAN_ONTOLOGY = master/owl/ccf_Lung_classes.owl

ORGAN =
ORGAN_ONTOLOGY =

tmp/$(ORGAN)-ont.owl:
	echo 'Pulling Organ specific ontology to take its terms'
	wget -O $@ https://raw.githubusercontent.com/hubmapconsortium/ccf-validation-tools/$(ORGAN_ONTOLOGY)
.PHONY: tmp/$(ORGAN)-ont.owl

tmp/$(ORGAN)-seed.txt: tmp/$(ORGAN)-ont.owl
	$(ROBOT) query --input $< --query seed_class.sparql $@.tmp.txt
	cat $@.tmp.txt $(SCATLAS_KEEPRELATIONS) | sed '/term/d' >$@ && rm $@.tmp.txt
.PHONY: tmp/$(ORGAN)-seed.txt

tmp/uberon-base.owl:
	wget -O $@ http://purl.obolibrary.org/obo/uberon/uberon-base.owl

tmp/cl-base.owl:
	wget -O $@ http://purl.obolibrary.org/obo/cl/cl-base.owl

tmp/ro.owl: $(SCATLAS_KEEPRELATIONS)
	wget -O $@ http://purl.obolibrary.org/obo/ro/ro.owl

tmp/merged_imports.owl: tmp/uberon-base.owl tmp/cl-base.owl tmp/ro.owl
	$(ROBOT) merge -i tmp/uberon-base.owl -i tmp/cl-base.owl -i tmp/ro.owl -o $@

tmp/materialize-direct.nt: tmp/merged_imports.owl $(SCATLAS_KEEPRELATIONS)
	$(RG) --ontology-file $< --properties-file $(SCATLAS_KEEPRELATIONS) --output-subclasses true --reflexive-subclasses false --output-file $@

tmp/$(ORGAN)-annotations.owl: tmp/merged_imports.owl tmp/$(ORGAN)-seed.txt
	$(ROBOT) filter --input $< --term-file tmp/$(ORGAN)-seed.txt --select "annotations" --output $@
.PHONY: tmp/$(ORGAN)-annotations.owl

tmp/$(ORGAN)-term.facts: tmp/$(ORGAN)-seed.txt
	cp $< $@.tmp.facts
	sed -e 's/^/</' -e 's/$\\r/>/' -e 's/$$/>/' -e 's/>>/>/' <$@.tmp.facts >$@ && rm $@.tmp.facts
.PHONY: tmp/$(ORGAN)-term.facts

tmp/rdf.facts: tmp/materialize-direct.nt
	sed 's/ /\t/' <$< | sed 's/ /\t/' | sed 's/ \.$$//' >$@
.PHONY: tmp/rdf.facts

tmp/ontrdf.facts: tmp/merged_imports.owl
	riot --output=ntriples $< | sed 's/ /\t/' | sed 's/ /\t/' | sed 's/ \.$$//' >$@
.PHONY: tmp/ontrdf.facts

tmp/nonredundant.facts ccf-$(ORGAN)-extended.nt: tmp/$(ORGAN)-term.facts tmp/rdf.facts tmp/ontrdf.facts prune.dl
	mv $< tmp/term.facts
	souffle -c --fact-dir=tmp prune.dl
	cp nonredundant.csv tmp/nonredundant.facts
	mv nonredundant.csv ccf-$(ORGAN)-extended.nt
.PHONY: tmp/nonredundant.facts ccf-$(ORGAN)-extended.nt

tmp/complete-transitive.ofn: tmp/term.facts tmp/nonredundant.facts tmp/ontrdf.facts convert_owl.dl 
	souffle -c --fact-dir=tmp convert_owl.dl
	sed -e '1s/^/Ontology(<http:\/\/purl.obolibrary.org\/obo\/$(ORGAN)-extended.owl>\n/' -e '$$s/$$/)/' <ofn.csv >$@ && rm ofn.csv
.PHONY: tmp/complete-transitive.ofn

owl/$(ORGAN)-extended.owl: tmp/complete-transitive.ofn tmp/$(ORGAN)-annotations.owl
	$(ROBOT) merge --input tmp/$(ORGAN)-annotations.owl --input tmp/complete-transitive.ofn \
					 remove --term $(SCATLAS_KEEPRELATIONS) --select complement --select object-properties --trim true -o $@

.PRECIOUS: owl/$(ORGAN)-extended.owl

graph/$(ORGAN)-extended.png: owl/$(ORGAN)-extended.owl ubergraph-style.json
	$(ROBOT) convert --input $< --output $<.json
	og2dot.js -s ubergraph-style.json $<.json > $<.dot 
	dot $<.dot -Tpng -Grankdir=LR > $@
	dot $<.dot -Tpdf -Grankdir=LR > $@.pdf
	rm $<.json
	rm $<.dot
	
