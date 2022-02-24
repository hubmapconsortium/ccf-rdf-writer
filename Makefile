ROBOT_ENV=ROBOT_JAVA_ARGS=-Xmx120G
ROBOT=$(ROBOT_ENV) robot
RG_ENV=JAVA_OPTS=-Xmx120G
RG=$(RG_ENV) relation-graph

SCATLAS_KEEPRELATIONS = relations.txt

kidney-ont.owl:
	echo 'Pulling Kidney ontology to take its terms'
	wget -O $@ https://raw.githubusercontent.com/hubmapconsortium/ccf-validation-tools/master/owl/ccf_Kidney_classes.owl

kidney-seed.txt: kidney-ont.owl
	$(ROBOT) query --input $< --query seed_class.sparql $@.tmp.txt
	cat $@.tmp.txt $(SCATLAS_KEEPRELATIONS) | sed '/term/d' >$@ && rm $@.tmp.txt

kidney-annotations.owl: kidney-ont.owl kidney-seed.txt
	$(ROBOT) filter --input kidney-ont.owl --term-file kidney-seed.txt --select "self annotations" --output $@

uberon-base.owl:
	wget -O $@ http://purl.obolibrary.org/obo/uberon/uberon-base.owl

cl-base.owl:
	wget -O $@ http://purl.obolibrary.org/obo/cl/cl-base.owl

merged_imports.owl: uberon-base.owl cl-base.owl
	$(ROBOT) merge -i uberon-base.owl -i cl-base.owl -o $@

materialize-direct.nt: merged_imports.owl
	$(RG) --ontology-file $< --property 'http://purl.obolibrary.org/obo/BFO_0000050' --output-file $@

.PHONY: materialize-direct.nt

term.facts: kidney-seed.txt
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
	sed -e '1s/^/Ontology(<http:\/\/purl.obolibrary.org\/obo\/kidney-extended.owl>\n/' -e '$$s/$$/)/' <ofn.csv >$@ && rm ofn.csv

.PHONY: complete-transitive.ofn

extended.owl: complete-transitive.ofn kidney-annotations.owl
	$(ROBOT) merge --input kidney-annotations.owl --input complete-transitive.ofn \
					 remove --term $(SCATLAS_KEEPRELATIONS) --select complement --select object-properties --trim true -o $@

.PHONY: extended.owl

kidney-extended.png: extended.owl ubergraph-style.json
	$(ROBOT) convert --input $< --output $<.json
	og2dot.js -s ubergraph-style.json $<.json > $<.dot 
	dot $<.dot -Tpng -Grankdir=LR > $@
	dot $<.dot -Tpdf -Grankdir=LR > $@.pdf

.PHONY: kidney-extended.png