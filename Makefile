ROBOT_ENV=ROBOT_JAVA_ARGS=-Xmx120G
ROBOT=$(ROBOT_ENV) robot
RG_ENV=JAVA_OPTS=-Xmx120G
RG=$(RG_ENV) relation-graph

SCATLAS_KEEPRELATIONS = relations.txt

ORGAN = kidney
ORGAN_ONTOLOGY = master/owl/ccf_Kidney_classes.owl

organ-ont.owl:
	echo 'Pulling Organ specific ontology to take its terms'
	wget -O $@ https://raw.githubusercontent.com/hubmapconsortium/ccf-validation-tools/$(ORGAN_ONTOLOGY)

organ-seed.txt: organ-ont.owl
	$(ROBOT) query --input $< --query seed_class.sparql $@.tmp.txt
	cat $@.tmp.txt $(SCATLAS_KEEPRELATIONS) | sed '/term/d' >$@ && rm $@.tmp.txt

organ-annotations.owl: organ-ont.owl organ-seed.txt
	$(ROBOT) filter --input organ-ont.owl --term-file organ-seed.txt --select "self annotations" --output $@

uberon-base.owl:
	wget -O $@ http://purl.obolibrary.org/obo/uberon/uberon-base.owl

cl-base.owl:
	wget -O $@ http://purl.obolibrary.org/obo/cl/cl-base.owl

merged_imports.owl: uberon-base.owl cl-base.owl
	$(ROBOT) merge -i uberon-base.owl -i cl-base.owl -o $@

materialize-direct.nt: merged_imports.owl
	$(RG) --ontology-file $< --property 'http://purl.obolibrary.org/obo/BFO_0000050' --output-file $@

.PHONY: materialize-direct.nt

term.facts: organ-seed.txt
	cp $< $@.tmp.facts
	sed -e 's/^/</' -e 's/\r/>/' <$@.tmp.facts >$@ && rm $@.tmp.facts

rdf.facts: materialize-direct.nt
	sed 's/ /\t/' <$< | sed 's/ /\t/' | sed 's/ \.$$//' >$@

.PHONY: rdf.facts

ontrdf.facts: merged_imports.owl
	riot --output=ntriples $< | sed 's/ /\t/' | sed 's/ /\t/' | sed 's/ \.$$//' >$@

.PHONY: ontrdf.facts

complete-transitive.ofn: term.facts rdf.facts ontrdf.facts convert.dl
	souffle -c convert.dl
	sed -e '1s/^/Ontology(<http:\/\/purl.obolibrary.org\/obo\/$(ORGAN)-extended.owl>\n/' -e '$$s/$$/)/' <ofn.csv >$@ && rm ofn.csv

.PHONY: complete-transitive.ofn

organ-extended.owl: complete-transitive.ofn organ-annotations.owl
	$(ROBOT) merge --input organ-annotations.owl --input complete-transitive.ofn \
					 remove --term $(SCATLAS_KEEPRELATIONS) --select complement --select object-properties --trim true -o $@

.PHONY: organ-extended.owl

organ-extended.png: organ-extended.owl ubergraph-style.json
	$(ROBOT) convert --input $< --output $<.json
	og2dot.js -s ubergraph-style.json $<.json > $<.dot 
	dot $<.dot -Tpng -Grankdir=LR > $@
	dot $<.dot -Tpdf -Grankdir=LR > $@.pdf

.PHONY: organ-extended.png